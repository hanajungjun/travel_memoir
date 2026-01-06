import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travel_memoir/storage_paths.dart';

class TravelListService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // =====================================================
  // 📌 전체 여행 목록
  // =====================================================
  static Future<List<Map<String, dynamic>>> getTravels() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final res = await _supabase
        .from('travels')
        .select(
          'id, title, travel_type, '
          // ✅ country_name 대신 다국어 컬럼 두 개를 모두 가져옵니다.
          'country_name_ko, country_name_en, '
          'region_name, province, '
          'start_date, end_date, is_completed, '
          'ai_cover_summary',
        )
        .order('start_date', ascending: false);

    final travels = List<Map<String, dynamic>>.from(res);

    return travels.map((t) => _normalizeTravel(t, user.id)).toList();
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

    // 🌐 [추가] 시스템 언어 확인
    final bool isKo = PlatformDispatcher.instance.locale.languageCode == 'ko';

    // ✅ [수정] 다국어 컬럼에서 국가 이름 추출
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
      // ✅ 여기서 이제 한국어/영어 국가명이 제목으로 들어갑니다.
      resolvedTitle = (countryName != null && countryName.toString().isNotEmpty)
          ? '$countryName 여행'
          : '해외 여행';
    } else {
      resolvedTitle = '여행';
    }

    // ---------- Storage URL 생성 ----------
    final coverUrl = _supabase.storage
        .from('travel_images')
        .getPublicUrl(StoragePaths.travelCover(userId, travelId));

    final mapUrl = _supabase.storage
        .from('travel_images')
        .getPublicUrl('${StoragePaths.travelRoot(userId, travelId)}/map.png');

    return {
      ...travel,
      'title': resolvedTitle,
      'display_country_name': countryName, // UI에서 편하게 쓰려고 추가
      'cover_image_url': coverUrl,
      'map_image_url': mapUrl,
    };
  }

  // =====================================================
  // 🕒 최근 여행지 (홈)
  // =====================================================
  static Future<List<Map<String, dynamic>>> getRecentTravels({
    int limit = 4,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final res = await _supabase
        .from('travels')
        .select(
          'id, title, travel_type, '
          // ✅ country_name 대신 다국어 컬럼 두 개를 모두 가져옵니다.
          'country_name_ko, country_name_en, '
          'region_name, '
          'start_date, end_date, is_completed',
        )
        .eq('is_completed', true)
        .order('completed_at', ascending: false)
        .limit(limit);

    final travels = List<Map<String, dynamic>>.from(res);

    // ✅ 여기서 _normalizeTravel을 호출할 때
    // 위에서 뽑아온 ko, en 컬럼을 사용해 제목을 언어별로 예쁘게 만들어줍니다.
    return travels.map((t) => _normalizeTravel(t, user.id)).toList();
  }

  // =====================================================
  // 🗺️ 국내 지도용 방문 province
  // =====================================================
  static Future<List<String>> getVisitedDomesticRegions() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final res = await _supabase
        .from('travels')
        .select('province')
        .eq('travel_type', 'domestic')
        .eq('is_completed', true)
        .not('province', 'is', null);

    return res.map<String>((e) => e['province'] as String).toSet().toList();
  }
}
