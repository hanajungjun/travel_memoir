import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travel_memoir/storage_paths.dart';

class TravelDayService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // 모든 보이지 않는 문자(공백, 줄바꿈, 탭 등)를 완전히 제거하는 핵심 함수
  static String _clean(String? input) {
    if (input == null) return '';
    return input.replaceAll(RegExp(r'[\s\n\r\t]+'), '').trim();
  }

  /// yyyy-MM-dd 형식 반환
  static String _dateOnly(DateTime d) => d
      .toIso8601String()
      .substring(0, 10)
      .replaceAll(RegExp(r'[\s\n\r\t]+'), '');

  // =====================================================
  // 🛡️ travel_day 데이터 정규화
  // =====================================================
  static Map<String, dynamic> _normalizeDay(Map<String, dynamic> day) {
    return {
      ...day,
      'text': (day['text'] as String?)?.trim() ?? '',
      'ai_summary': (day['ai_summary'] as String?)?.trim() ?? '',
      'ai_style': _clean(day['ai_style'] as String? ?? 'default'),
      'date': _clean(day['date'] as String?) ?? _dateOnly(DateTime.now()),
      'is_completed': day['is_completed'] == true,
      'photo_urls': day['photo_urls'] ?? [],
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

    final String tid = _clean(travelId);

    final res = await _supabase
        .from('travel_days')
        .select()
        .eq('travel_id', tid)
        .eq('date', _dateOnly(date))
        .maybeSingle();

    if (res == null) return null;

    return _normalizeDay(Map<String, dynamic>.from(res));
  }

  // =====================================================
  // 💾 일기 저장 (GitHub 버전: ai_image_url 컬럼 없음)
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
    if (user == null) throw Exception('로그인이 필요합니다.');

    final String tid = _clean(travelId);

    final res = await _supabase
        .from('travel_days')
        .upsert({
          'travel_id': tid,
          'day_index': dayIndex,
          'date': _dateOnly(date),
          'text': text.trim(),
          'ai_summary': aiSummary?.trim(),
          'ai_style': _clean(aiStyle) != '' ? _clean(aiStyle) : 'default',
        }, onConflict: 'travel_id,date')
        .select()
        .single();

    return _normalizeDay(Map<String, dynamic>.from(res));
  }

  // =====================================================
  // 🤖 AI 이미지 URL (새 표준: ai_generated.png 고정)
  // =====================================================
  static String? getAiImageUrl({
    required String travelId,
    required String diaryId,
  }) {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final uid = _clean(user.id);
    final tid = _clean(travelId);
    final did = _clean(diaryId);

    // ✅ 우리가 약속한 새 경로로 강제 고정
    final String cleanPath =
        'users/$uid/travels/$tid/diaries/$did/ai_generated.png';

    try {
      final url = _supabase.storage
          .from('travel_images')
          .getPublicUrl(cleanPath);

      final cleanUrl = _clean(url);
      if (cleanUrl.isEmpty) return null;

      return cleanUrl;
    } catch (_) {
      return null;
    }
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

    final String tid = _clean(travelId);

    await _supabase
        .from('travel_days')
        .update({'is_completed': true})
        .eq('travel_id', tid)
        .eq('date', _dateOnly(date));

    final travel = await _supabase
        .from('travels')
        .select('start_date, end_date, is_completed')
        .eq('id', tid)
        .single();

    if (travel['is_completed'] == true) return false;

    final startDate = DateTime.parse(travel['start_date']);
    final endDate = DateTime.parse(travel['end_date']);
    final expectedDays = endDate.difference(startDate).inDays + 1;

    final completedDays = await _supabase
        .from('travel_days')
        .select('id')
        .eq('travel_id', tid)
        .eq('is_completed', true);

    if (completedDays.length != expectedDays) return false;

    await _supabase
        .from('travels')
        .update({
          'is_completed': true,
          'completed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', tid);

    return true;
  }

  static Future<int> getWrittenDayCount({required String travelId}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 0;
    final res = await _supabase
        .from('travel_days')
        .select('text')
        .eq('travel_id', _clean(travelId));
    if (res is! List) return 0;
    return res
        .where((row) => (row['text'] ?? '').toString().trim().isNotEmpty)
        .length;
  }

  static Future<List<Map<String, dynamic>>> getDiariesByTravel({
    required String travelId,
  }) async {
    final res = await _supabase
        .from('travel_days')
        .select()
        .eq('travel_id', _clean(travelId))
        .order('date');
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<List<Map<String, dynamic>>> getAlbumDays({
    required String travelId,
  }) async {
    final res = await _supabase
        .from('travel_days')
        .select('date, ai_summary')
        .eq('travel_id', _clean(travelId))
        .order('date', ascending: true);
    if (res is! List) return [];
    return res
        .where((e) => e['date'] != null)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Future<Map<String, dynamic>> getTravelById(String travelId) async {
    return await _supabase
        .from('travels')
        .select()
        .eq('id', _clean(travelId))
        .single();
  }

  static Future<void> updateDiaryPhotos({
    required String travelId,
    required DateTime date,
    required List<String> photoUrls,
  }) async {
    await _supabase
        .from('travel_days')
        .update({'photo_urls': photoUrls})
        .eq('travel_id', _clean(travelId))
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
    final tid = _clean(travelId);
    final uid = _clean(user.id);
    List<String> pathsToDelete = [];
    try {
      final diary = await supabase
          .from('travel_days')
          .select('id')
          .eq('travel_id', tid)
          .eq('date', date.trim())
          .maybeSingle();
      if (diary != null) {
        pathsToDelete.add(
          _clean(StoragePaths.travelDayImage(uid, tid, diary['id'].toString())),
        );
      }
    } catch (e) {}
    pathsToDelete.add(_clean(StoragePaths.travelCover(uid, tid)));
    pathsToDelete.add(_clean(StoragePaths.travelMap(uid, tid)));
    if (photoUrls != null) {
      for (var url in photoUrls) {
        try {
          final uri = Uri.parse(url.toString());
          pathsToDelete.add(
            _clean(
              uri.pathSegments
                  .skip(uri.pathSegments.indexOf('travel_images') + 1)
                  .join('/'),
            ),
          );
        } catch (e) {}
      }
    }
    if (pathsToDelete.isNotEmpty) {
      try {
        await supabase.storage
            .from('travel_images')
            .remove(pathsToDelete.toSet().toList());
      } catch (e) {}
    }
    await supabase
        .from('travel_days')
        .update({
          'text': '',
          'ai_summary': null,
          'ai_style': null,
          'photo_urls': [],
          'is_completed': false,
        })
        .eq('travel_id', tid)
        .eq('date', date.trim());
  }
}
