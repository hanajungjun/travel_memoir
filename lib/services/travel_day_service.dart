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
  // 💾 일기 저장 (수정본)
  // =====================================================
  static Future<Map<String, dynamic>> upsertDiary({
    required String travelId,
    required int dayIndex,
    required DateTime date,
    required String text,
    String? aiSummary,
    String? aiStyle,
    String? existingId, // 🎯 [추가] 기존 일기 ID가 있으면 받습니다.
    bool skipDateUpdate = false, // 🎯 [추가] 순서 변경 중일 땐 날짜 업데이트 스킵용
  }) async {
    final Map<String, dynamic> saveData = {
      'travel_id': _clean(travelId),
      'day_index': dayIndex,
      'date': _dateOnly(date),
      'text': text.trim(),
      'ai_summary': aiSummary?.trim(),
      'ai_style': _clean(aiStyle) != '' ? _clean(aiStyle) : 'default',
    };

    // 🎯 [핵심] 만약 기존 ID가 있다면, 날짜 충돌 걱정 없이 해당 ID 레코드를 업데이트합니다.
    if (existingId != null && existingId.isNotEmpty) {
      saveData['id'] = existingId;
    }

    final res = await _supabase
        .from('travel_days')
        .upsert(saveData, onConflict: 'id') // 🎯 [변경] ID 충돌로 처리하여 기존 데이터 보호
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
    List<String>? photoPaths, // 이제 이 리스트에만 의존하지 않습니다!
  }) async {
    final tid = _clean(travelId);
    final uid = _clean(userId);
    final trimmedDate = date.trim();

    try {
      // 1. 해당 일기의 ID를 먼저 가져옵니다.
      final diary = await _supabase
          .from('travel_days')
          .select('id')
          .eq('travel_id', tid)
          .eq('date', trimmedDate)
          .maybeSingle();

      if (diary == null) return;
      final String diaryId = diary['id'].toString();

      // 2. [핵심] moments 폴더 경로를 특정합니다.
      final String momentsPath =
          'users/$uid/travels/$tid/diaries/$diaryId/moments';

      // 3. Storage에서 해당 폴더에 있는 파일 목록을 직접 조회합니다.
      final List<FileObject> folderFiles = await _supabase.storage
          .from('travel_images')
          .list(path: momentsPath);

      List<String> finalDeleteList = [];

      // 폴더 내 파일이 있다면 삭제 목록에 추가
      if (folderFiles.isNotEmpty) {
        finalDeleteList.addAll(
          folderFiles.map((f) => '$momentsPath/${f.name}'),
        );
      }

      // AI 이미지 경로도 추가 (기존 로직 유지)
      finalDeleteList.add(
        'users/$uid/travels/$tid/diaries/$diaryId/ai_generated.jpg',
      );

      // 기타 커버/지도 이미지 (필요시)
      finalDeleteList.add('users/$uid/travels/$tid/travel_cover.png');
      finalDeleteList.add('users/$uid/travels/$tid/travel_map.png');

      // 4. [소탕 실시] 수집된 모든 경로를 한 번에 삭제합니다.
      if (finalDeleteList.isNotEmpty) {
        await _supabase.storage
            .from('travel_images')
            .remove(finalDeleteList.toSet().toList());
      }

      // 5. 마지막으로 DB 정보를 비웁니다.
      await _supabase
          .from('travel_days')
          .update({
            'text': '',
            'ai_summary': null,
            'ai_style': null,
            'photo_urls': [], // DB 리스트 초기화
            'is_completed': false,
          })
          .eq('travel_id', tid)
          .eq('date', trimmedDate);

      // ✅ [추가] 부모 여행 상태도 미완료로 리셋!
      await _supabase
          .from('travels')
          .update({'is_completed': false}) // 여행(부모) 미완료 처리
          .eq('id', tid);

      debugPrint('✅ [소탕완료] Moments 폴더 및 DB 초기화 성공');
    } catch (e) {
      debugPrint('❌ [소탕실패] 에러 발생: $e');
      rethrow;
    }
  }

  static String? getAiImageUrl({
    required String userId,
    required String travelId,
    required String diaryId,
  }) {
    final path =
        'users/$userId/travels/$travelId/diaries/$diaryId/ai_generated.jpg';
    final url = Supabase.instance.client.storage
        .from('travel_images')
        .getPublicUrl(path);
    return url;
  }
}
