import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travel_memoir/storage_paths.dart';

class TravelDayService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static String _clean(String? input) {
    if (input == null) return '';
    return input.replaceAll(RegExp(r'[\s\n\r\t]+'), '').trim();
  }

  static String _dateOnly(DateTime d) => d.toIso8601String().substring(0, 10);

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
    final res = await _supabase
        .from('travel_days')
        .select()
        .eq('travel_id', _clean(travelId))
        .eq('date', _dateOnly(date))
        .maybeSingle();

    if (res == null) return null;
    return _normalizeDay(Map<String, dynamic>.from(res));
  }

  // =====================================================
  // 💾 일기 저장
  // =====================================================
  static Future<Map<String, dynamic>> upsertDiary({
    required String travelId,
    required int dayIndex,
    required DateTime date,
    required String text,
    String? aiSummary,
    String? aiStyle,
  }) async {
    final res = await _supabase
        .from('travel_days')
        .upsert({
          'travel_id': _clean(travelId),
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
  // 🤖 AI 이미지 URL (path → UI에서 URL 변환)
  // =====================================================
  static String? getAiImagePath({
    required String userId,
    required String travelId,
    required String diaryId,
  }) {
    return StoragePaths.travelDayImagePath(
      _clean(userId),
      _clean(travelId),
      _clean(diaryId),
    );
  }

  // =====================================================
  // ✅ 일기작성완료 + 여행완료 체크
  // =====================================================
  static Future<bool> completeDayAndCheckTravel({
    required String travelId,
    required DateTime date,
  }) async {
    final tid = _clean(travelId);

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
        .order('date');

    if (res is! List) return [];

    return res
        .where((e) => e['date'] != null)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Future<void> updateDiaryPhotos({
    required String travelId,
    required DateTime date,
    required List<String> photoPaths,
  }) async {
    await _supabase
        .from('travel_days')
        .update({'photo_urls': photoPaths})
        .eq('travel_id', _clean(travelId))
        .eq('date', _dateOnly(date));
  }

  static Future<void> clearDiaryRecord({
    required String userId,
    required String travelId,
    required String date,
    List<String>? photoPaths,
  }) async {
    final tid = _clean(travelId);
    final uid = _clean(userId);

    final List<String> pathsToDelete = [];

    try {
      final diary = await _supabase
          .from('travel_days')
          .select('id')
          .eq('travel_id', tid)
          .eq('date', date.trim())
          .maybeSingle();

      if (diary != null) {
        pathsToDelete.add(
          StoragePaths.travelDayImagePath(uid, tid, diary['id'].toString()),
        );
      }
    } catch (_) {}

    pathsToDelete.add(StoragePaths.travelCoverPath(uid, tid));
    pathsToDelete.add(StoragePaths.travelMapPath(uid, tid));

    if (photoPaths != null) {
      pathsToDelete.addAll(photoPaths.map(_clean));
    }

    if (pathsToDelete.isNotEmpty) {
      await _supabase.storage
          .from('travel_images')
          .remove(pathsToDelete.toSet().toList());
    }

    await _supabase
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

  static String? getAiImageUrl({
    required String userId,
    required String travelId,
    required String diaryId,
  }) {
    final path =
        'users/$userId/travels/$travelId/diaries/$diaryId/ai_generated.png';
    final url = Supabase.instance.client.storage
        .from('travel_images')
        .getPublicUrl(path);
    return url;
  }
}
