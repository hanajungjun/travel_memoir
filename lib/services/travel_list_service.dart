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
          'country_name, region_name, province, '
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
    final countryName = travel['country_name'] as String?;
    final regionName = travel['region_name'] as String?;

    // ---------- title 결정 ----------
    String resolvedTitle;
    if (rawTitle.isNotEmpty) {
      resolvedTitle = rawTitle;
    } else if (travelType == 'domestic') {
      resolvedTitle = (regionName != null && regionName.isNotEmpty)
          ? '$regionName 여행'
          : '국내 여행';
    } else if (travelType == 'overseas') {
      resolvedTitle = (countryName != null && countryName.isNotEmpty)
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

      // 🔥 이제 DB값이 아니라 “계산된 URL”
      'cover_image_url': coverUrl,
      'map_image_url': mapUrl,
    };
  }

  // =====================================================
  // 🕒 최근 여행 (홈)
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
          'country_name, region_name, '
          'start_date, end_date, is_completed',
        )
        .eq('is_completed', true)
        .order('completed_at', ascending: false)
        .limit(limit);

    final travels = List<Map<String, dynamic>>.from(res);

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
