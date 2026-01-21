import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travel_memoir/storage_paths.dart'; // 🎯 경로 관리 클래스 임포트 확인

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
            'id, title, travel_type, '
            'country_name_ko, country_name_en, country_code, '
            'region_name, region_id, province, region_key, '
            'start_date, end_date, is_completed, '
            'ai_cover_summary, completed_at',
          )
          .order('start_date', ascending: false);

      final travels = List<Map<String, dynamic>>.from(res);
      return travels.map((t) => _normalizeTravel(t, user.id)).toList();
    } catch (e) {
      debugPrint('❌ [getTravels] Error: $e');
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

    // ---------- 1. title 결정 ----------
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

    // ---------- 2. Storage URL 생성 (StoragePaths 통합 관리) ----------

    // 여행 대표 커버 이미지 (이미 완성된 URL을 반환하도록 수정된 StoragePaths 기준)
    final coverUrl = StoragePaths.travelCover(userId, travelId);

    // 🎯 [핵심 수정] 지도 이미지 URL 결정
    String? mapUrl;
    if (regionKey != null && regionKey.isNotEmpty) {
      if (travelType == 'usa') {
        // 미국 버킷: usa_map_image
        mapUrl = StoragePaths.usaMap(regionKey);
      } else if (travelType == 'domestic') {
        // 국내 버킷: map_images
        mapUrl = StoragePaths.domesticMap(regionKey);
      } else if (travelType == 'overseas') {
        // 해외 버킷: global_map_image
        mapUrl = StoragePaths.globalMap(regionKey);
      }
    }

    return {
      ...travel,
      'title': resolvedTitle,
      'display_country_name': countryName,
      'cover_image_url': coverUrl,
      'map_image_url': mapUrl, // 🎯 이제 타입에 맞는 버킷 주소가 들어감
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
          // 💡 참고: is_completed가 true인 것만 가져오는지 확인 필요
          .order('start_date', ascending: false)
          .limit(limit);

      final travels = List<Map<String, dynamic>>.from(res);
      return travels.map((t) => _normalizeTravel(t, user.id)).toList();
    } catch (e) {
      debugPrint('❌ [getRecentTravels] Error: $e');
      return [];
    }
  }
}
