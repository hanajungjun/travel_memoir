import 'dart:io';
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travel_memoir/storage_paths.dart';

class TravelListService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // =====================================================
  // 📌 전체 여행 목록 (UI에서 필요한 모든 컬럼 포함)
  // =====================================================
  static Future<List<Map<String, dynamic>>> getTravels() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final res = await _supabase
          .from('travels')
          .select(
            'id, title, travel_type, '
            'country_name_ko, country_name_en, country_code, ' // ✅ country_code 추가
            'region_name, region_id, province, region_key, ' // ✅ region_id, region_key 추가
            'start_date, end_date, is_completed, '
            'ai_cover_summary, completed_at',
          )
          .order('start_date', ascending: false);

      final travels = List<Map<String, dynamic>>.from(res);
      return travels.map((t) => _normalizeTravel(t, user.id)).toList();
    } catch (e) {
      print('❌ [getTravels] Error: $e');
      return [];
    }
  }

  // =====================================================
  // 🧠 travel 데이터 정규화 + URL 생성
  // =====================================================
  static Map<String, dynamic> _normalizeTravel(
    Map<String, dynamic> travel,
    String userId,
  ) {
    final travelId = travel['id'] as String;
    final rawTitle = (travel['title'] ?? '').toString().trim();
    final travelType = travel['travel_type'] as String?;
    final regionName = travel['region_name'] as String?;
    final String? regionKey = travel['region_key'];

    final bool isKo = PlatformDispatcher.instance.locale.languageCode == 'ko';
    final countryName = isKo
        ? travel['country_name_ko']
        : travel['country_name_en'];

    // ---------- title 결정 ----------
    String resolvedTitle;
    if (rawTitle.isNotEmpty) {
      resolvedTitle = rawTitle;
    } else if (travelType == 'domestic') {
      resolvedTitle = (regionName != null && regionName.isNotEmpty)
          ? '$regionName 여행'
          : '국내 여행';
    } else if (travelType == 'overseas') {
      resolvedTitle = (countryName != null && countryName.toString().isNotEmpty)
          ? '$countryName 여행'
          : '해외 여행';
    } else {
      resolvedTitle = '여행';
    }

    // ---------- Storage URL 생성 (신/구 로직 공존) ----------
    final coverUrl = _supabase.storage
        .from('travel_images')
        .getPublicUrl(StoragePaths.travelCover(userId, travelId));

    String? mapUrl;
    if (regionKey != null && regionKey.isNotEmpty) {
      mapUrl = _supabase.storage
          .from('map_images')
          .getPublicUrl('$regionKey.png');
    } else {
      mapUrl = null;
    }

    return {
      ...travel,
      'title': resolvedTitle,
      'display_country_name': countryName,
      'cover_image_url': coverUrl,
      'map_image_url': mapUrl,
    };
  }

  // =====================================================
  // 🕒 최근 여행지 (홈 화면용)
  // =====================================================
  static Future<List<Map<String, dynamic>>> getRecentTravels({
    int limit = 4,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final res = await _supabase
          .from('travels')
          .select(
            'id, title, travel_type, region_key, '
            'country_name_ko, country_name_en, '
            'region_name, start_date, end_date, is_completed, completed_at',
          )
          .eq('is_completed', true)
          .order('completed_at', ascending: false)
          .limit(limit);

      final travels = List<Map<String, dynamic>>.from(res);
      return travels.map((t) => _normalizeTravel(t, user.id)).toList();
    } catch (e) {
      print('❌ [getRecentTravels] Error: $e');
      return [];
    }
  }
}
