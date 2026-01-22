import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TravelListService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // =====================================================
  // 📌 전체 여행 목록
  // =====================================================
  static Future<List<Map<String, dynamic>>> getTravels() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final res = await _supabase
          .from('travels')
          .select(
            'id ,user_id ,title, travel_type, '
            'country_name_ko, country_name_en, country_code, '
            'region_name, region_id, province, region_key, '
            'start_date, end_date, is_completed, '
            'ai_cover_summary, completed_at, '
            'cover_image_url, map_image_url',
          )
          .order('start_date', ascending: false);

      final travels = List<Map<String, dynamic>>.from(res);
      return travels.map(_normalizeTravel).toList();
    } catch (e) {
      debugPrint('❌ [getTravels] Error: $e');
      return [];
    }
  }

  // =====================================================
  // 🧠 travel 데이터 정규화 (URL은 그대로 사용)
  // =====================================================
  static Map<String, dynamic> _normalizeTravel(Map<String, dynamic> travel) {
    final rawTitle = (travel['title'] ?? '').toString().trim();
    final travelType = travel['travel_type'] as String?;
    final regionName = travel['region_name'] as String?;

    final bool isKo = PlatformDispatcher.instance.locale.languageCode == 'ko';
    final countryName = isKo
        ? travel['country_name_ko']
        : travel['country_name_en'];

    // ---------- title ----------
    String resolvedTitle;
    if (rawTitle.isNotEmpty) {
      resolvedTitle = rawTitle;
    } else if (travelType == 'domestic') {
      resolvedTitle = (regionName != null && regionName.isNotEmpty)
          ? '$regionName 여행'
          : '국내 여행';
    } else if (travelType == 'usa') {
      resolvedTitle = (regionName != null && regionName.isNotEmpty)
          ? '$regionName 여행'
          : '미국 여행';
    } else if (travelType == 'overseas') {
      resolvedTitle = (countryName != null && countryName.toString().isNotEmpty)
          ? '$countryName 여행'
          : '해외 여행';
    } else {
      resolvedTitle = '여행';
    }

    return {
      ...travel,
      'title': resolvedTitle,
      'display_country_name': countryName,
      // ✅ DB 값 그대로
      'cover_image_url': travel['cover_image_url'],
      'map_image_url': travel['map_image_url'],
    };
  }

  // =====================================================
  // 🕒 최근 여행지
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
            'id, user_id,title, travel_type, region_key, '
            'country_name_ko, country_name_en, '
            'region_name, start_date, end_date, '
            'is_completed, completed_at, '
            'cover_image_url, map_image_url',
          )
          .order('start_date', ascending: false)
          .limit(limit);

      final travels = List<Map<String, dynamic>>.from(res);
      return travels.map(_normalizeTravel).toList();
    } catch (e) {
      debugPrint('❌ [getRecentTravels] Error: $e');
      return [];
    }
  }
}
