import 'package:supabase_flutter/supabase_flutter.dart';

class TravelListService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> getTravels() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final res = await _supabase
        .from('travels')
        .select(
          'id, title, travel_type, '
          'country_name, region_name, province, '
          'start_date, end_date, is_completed, '
          'cover_image_url, map_image_url, ai_cover_summary',
        )
        .order('start_date', ascending: false);

    final List<Map<String, dynamic>> travels = List<Map<String, dynamic>>.from(
      res,
    );

    return travels.map(_normalizeTravel).toList();
  }

  // ==============================
  // 🛡️ travel 데이터 정규화 (최종)
  // ==============================
  static Map<String, dynamic> _normalizeTravel(Map<String, dynamic> travel) {
    final String? rawTitle = travel['title'] as String?;
    final String? travelType = travel['travel_type'] as String?;
    final String? countryName = travel['country_name'] as String?;
    final String? regionName = travel['region_name'] as String?;
    final String? coverUrl = travel['cover_image_url'] as String?;

    String resolvedTitle;

    // 1️⃣ title이 이미 있으면 최우선
    if (rawTitle != null && rawTitle.trim().isNotEmpty) {
      resolvedTitle = rawTitle.trim();
    }
    // 2️⃣ 국내 여행 → region_name
    else if (travelType == 'domestic') {
      if (regionName != null && regionName.trim().isNotEmpty) {
        resolvedTitle = '${regionName.trim()} 여행';
      } else {
        resolvedTitle = '국내 여행';
      }
    }
    // 3️⃣ 해외 여행 → country_name
    else if (travelType == 'overseas') {
      if (countryName != null && countryName.trim().isNotEmpty) {
        resolvedTitle = '${countryName.trim()} 여행';
      } else {
        resolvedTitle = '해외 여행';
      }
    }
    // 4️⃣ 최후 fallback
    else {
      resolvedTitle = '여행';
    }

    return {
      ...travel,
      'title': resolvedTitle,

      // 이미지 null 정리
      'cover_image_url': (coverUrl != null && coverUrl.trim().isNotEmpty)
          ? coverUrl
          : null,
    };
  }

  // ==============================
  // 🗺️ 국내 지도용 방문 지역 (province 기준)
  // ==============================
  static Future<List<String>> getVisitedDomesticRegions() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final res = await _supabase
        .from('travels')
        .select('province')
        .eq('travel_type', 'domestic')
        .eq('is_completed', true)
        .not('province', 'is', null);

    // 중복 제거 + null 방어
    return res.map<String>((e) => e['province'] as String).toSet().toList();
  }

  static Future<List<Map<String, dynamic>>> getRecentTravels({
    int limit = 4, //3개이상일때만 see all 보이게
  }) async {
    final res = await Supabase.instance.client
        .from('travels')
        .select()
        .eq('is_completed', true) // ✅ 핵심
        .order('completed_at', ascending: false) // ✅ 완료 최신순
        .limit(limit);

    return List<Map<String, dynamic>>.from(res);
  }
}
