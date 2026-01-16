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
  // 💾 일기 저장 (에러 박멸용 최종 버전)
  // =====================================================
  static Future<Map<String, dynamic>> upsertDiary({
    required String travelId,
    required int dayIndex,
    required DateTime date,
    required String text,
    String? aiSummary,
    String? aiStyle,
    String? aiImageUrl, // ✅ AI 이미지 URL을 받도록 추가됨
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('need login');

    final res = await _supabase
        .from('travel_days')
        .upsert({
          'travel_id': travelId,
          'day_index': dayIndex,
          'date': _dateOnly(date),
          'text': text.trim(),
          'ai_summary': aiSummary?.trim(),
          'ai_style': aiStyle?.trim() ?? 'default',
          'ai_image_url': aiImageUrl, // ✅ DB 컬럼에 URL 저장
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
  // =====================================================ㅋ
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
    List<dynamic>? photoUrls,
  }) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // 삭제할 경로들을 담을 리스트
    List<String> pathsToDelete = [];

    // --- 1️⃣ AI 생성 일기 이미지 경로 추가 ---
    try {
      final diary = await supabase
          .from('travel_days')
          .select('id')
          .eq('travel_id', travelId)
          .eq('date', date)
          .maybeSingle();

      if (diary != null) {
        final diaryId = diary['id'];
        pathsToDelete.add(
          StoragePaths.travelDayImage(user.id, travelId, diaryId),
        );
      }
    } catch (e) {
      debugPrint('⚠️ diary list failed: $e');
    }

    // --- 2️⃣ 여행 대표 이미지 경로 추가 (Cover, Map) ---
    // 수정/삭제 시 무조건 지워야 하는 대표 이미지들
    pathsToDelete.add(StoragePaths.travelCover(user.id, travelId));
    pathsToDelete.add(StoragePaths.travelMap(user.id, travelId));
    pathsToDelete.add(StoragePaths.travelTimeline(user.id, travelId));

    // --- 3️⃣ 사용자 업로드 사진 경로 추가 ---
    if (photoUrls != null && photoUrls.isNotEmpty) {
      for (var url in photoUrls) {
        try {
          final uri = Uri.parse(url.toString());
          final path = uri.pathSegments
              .skip(uri.pathSegments.indexOf('travel_images') + 1)
              .join('/');
          pathsToDelete.add(path);
        } catch (e) {
          debugPrint('⚠️ phote parsing error: $e');
        }
      }
    }

    // --- 4️⃣ 일괄 삭제 실행 (중요) ---
    if (pathsToDelete.isNotEmpty) {
      try {
        // 중복 경로 제거 후 한꺼번에 삭제 요청
        final uniquePaths = pathsToDelete.toSet().toList();
        await supabase.storage.from('travel_images').remove(uniquePaths);
        debugPrint('🗑️ 관련 스토리지 파일 일괄 삭제 완료 (${uniquePaths.length}개)');
      } catch (e) {
        // 파일이 없는 경우 400이나 404가 뜰 수 있으나 무시해도 됨
        debugPrint('ℹ️ 일부 파일 삭제 건너뜀 또는 에러: $e');
      }
    }

    // --- 5️⃣ DB 데이터 초기화 (기존과 동일) ---
    await supabase
        .from('travel_days')
        .update({
          'text': '',
          'ai_summary': null,
          'ai_style': null,
          'photo_urls': [],
          'is_completed': false,
        })
        .eq('travel_id', travelId)
        .eq('date', date);
  }
}
