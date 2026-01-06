import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travel_memoir/storage_paths.dart';

class TravelDayService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// yyyy-MM-dd
  static String _dateOnly(DateTime d) => d.toIso8601String().substring(0, 10);

  // =====================================================
  // 🛡️ travel_day 정규화 (🔥 핵심)
  // =====================================================
  static Map<String, dynamic> _normalizeDay(Map<String, dynamic> day) {
    final String? text = day['text'] as String?;
    final String? aiSummary = day['ai_summary'] as String?;
    final String? aiStyle = day['ai_style'] as String?;
    final String? dateRaw = day['date'] as String?;

    return {
      ...day,
      'text': text?.trim() ?? '',
      'ai_summary': aiSummary?.trim() ?? '',
      'ai_style': (aiStyle != null && aiStyle.trim().isNotEmpty)
          ? aiStyle
          : 'default',
      'date': dateRaw ?? _dateOnly(DateTime.now()),
      'is_completed': day['is_completed'] == true,
    };
  }

  // =====================================================
  // 📌 특정 날짜 일기 조회
  // =====================================================
  static Future<Map<String, dynamic>?> getDiaryByDate({
    required String travelId,
    required DateTime date,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final res = await _supabase
        .from('travel_days')
        .select()
        .eq('travel_id', travelId)
        .eq('date', _dateOnly(date))
        .maybeSingle();

    if (res == null) return null;

    return _normalizeDay(Map<String, dynamic>.from(res));
  }

  // =====================================================
  // 💾 일기 저장 (없으면 insert, 있으면 update)
  // =====================================================
  static Future<Map<String, dynamic>> upsertDiary({
    required String travelId,
    required int dayIndex,
    required DateTime date,
    required String text,
    String? aiSummary,
    String? aiStyle,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('로그인 필요');
    }

    final res = await _supabase
        .from('travel_days')
        .upsert({
          'travel_id': travelId,
          'day_index': dayIndex,
          'date': _dateOnly(date),
          'text': text.trim(),
          'ai_summary': aiSummary?.trim(),
          'ai_style': aiStyle?.trim() ?? 'default',
        }, onConflict: 'travel_id,date')
        .select()
        .single();

    return _normalizeDay(Map<String, dynamic>.from(res));
  }

  // =====================================================
  // 🤖 AI 이미지 URL (🔥 ID 기반으로 수정됨)
  // =====================================================
  static String? getAiImageUrl({
    required String travelId,
    required String diaryId, // ✅ 고유 ID(UUID)를 받습니다.
  }) {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    // StoragePaths에도 diaryId를 넘겨주도록 수정되어 있어야 합니다!
    final path = StoragePaths.travelDayImage(user.id, travelId, diaryId);

    return _supabase.storage.from('travel_images').getPublicUrl(path);
  }

  // =====================================================
  // ✅ 별칭 (중복 제거 및 ID 기반 통합)
  // =====================================================
  static String? getDiaryImageUrl({
    required String travelId,
    required String diaryId, // ✅ String diaryId로 통일
  }) {
    return getAiImageUrl(travelId: travelId, diaryId: diaryId);
  }

  // =====================================================
  // ✅ 일기작성완료 + 여행완료 체크
  // =====================================================
  static Future<bool> completeDayAndCheckTravel({
    required String travelId,
    required DateTime date,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    await _supabase
        .from('travel_days')
        .update({'is_completed': true})
        .eq('travel_id', travelId)
        .eq('date', _dateOnly(date));

    final travel = await _supabase
        .from('travels')
        .select('start_date, end_date, is_completed')
        .eq('id', travelId)
        .single();

    if (travel['is_completed'] == true) return false;

    final startDate = DateTime.parse(travel['start_date']);
    final endDate = DateTime.parse(travel['end_date']);
    final expectedDays = endDate.difference(startDate).inDays + 1;

    final completedDays = await _supabase
        .from('travel_days')
        .select('id')
        .eq('travel_id', travelId)
        .eq('is_completed', true);

    if (completedDays.length != expectedDays) return false;

    await _supabase
        .from('travels')
        .update({
          'is_completed': true,
          'completed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', travelId);

    return true;
  }

  // =====================================================
  // ✍️ 작성 완료된 일기 개수
  // =====================================================
  static Future<int> getWrittenDayCount({required String travelId}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 0;

    final res = await _supabase
        .from('travel_days')
        .select('text')
        .eq('travel_id', travelId);

    if (res is! List) return 0;

    return res.where((row) {
      final text = (row['text'] ?? '').toString().trim();
      return text.isNotEmpty;
    }).length;
  }

  static Future<List<Map<String, dynamic>>> getDiariesByTravel({
    required String travelId,
  }) async {
    final res = await _supabase
        .from('travel_days')
        .select()
        .eq('travel_id', travelId)
        .order('date');

    return List<Map<String, dynamic>>.from(res);
  }

  // =====================================================
  // 🖼️ 앨범용 날짜 목록
  // =====================================================
  static Future<List<Map<String, dynamic>>> getAlbumDays({
    required String travelId,
  }) async {
    final res = await _supabase
        .from('travel_days')
        .select('date, ai_summary')
        .eq('travel_id', travelId)
        .order('date', ascending: true);

    if (res is! List) return [];

    return res
        .where((e) => e['date'] != null)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Future<Map<String, dynamic>> getTravelById(String travelId) async {
    return await _supabase.from('travels').select().eq('id', travelId).single();
  }

  // =====================================================
  // 📸 사용자 사진 URL 저장
  // =====================================================
  static Future<void> updateDiaryPhotos({
    required String travelId,
    required DateTime date,
    required List<String> photoUrls,
  }) async {
    await _supabase
        .from('travel_days')
        .update({'photo_urls': photoUrls})
        .eq('travel_id', travelId)
        .eq('date', _dateOnly(date));
  }

  static Future<void> clearDiaryRecord({
    required String travelId,
    required String date,
    List<dynamic>? photoUrls, // 사용자가 올린 사진들
  }) async {
    final supabase = Supabase.instance.client;

    // 1️⃣ 사용자가 직접 올린 사진들(photo_urls) Storage에서 삭제
    if (photoUrls != null && photoUrls.isNotEmpty) {
      for (var url in photoUrls) {
        try {
          final uri = Uri.parse(url.toString());
          // 'travel_images' 버킷 이후의 실제 파일 경로만 추출
          final path = uri.pathSegments
              .skip(uri.pathSegments.indexOf('travel_images') + 1)
              .join('/');
          await supabase.storage.from('travel_images').remove([path]);
          debugPrint('✅ 사용자 사진 삭제 완료: $path');
        } catch (e) {
          debugPrint('⚠️ 사진 삭제 실패: $e');
        }
      }
    }

    // 2️⃣ DB 데이터 초기화 (Row는 유지, 필드만 비움)
    await supabase
        .from('travel_days')
        .update({
          'text': '', // 일기 내용 비우기
          'ai_summary': null, // AI 요약 비우기
          'ai_style': null, // AI 이미지 정보 비우기 (사용자 요청 반영)
          'photo_urls': [], // 사용자 사진 리스트 비우기
          'is_completed': false, // ✅ [추가] 일기를 지웠으므로 완료 상태를 false로 변경
        })
        .eq('travel_id', travelId)
        .eq('date', date);
  }
}
