// map_data_service.dart
// Supabase와의 모든 통신을 담당하는 서비스 레이어.
// UI와 완전히 분리되어 있어 단독 테스트 가능.

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travel_memoir/features/map/widgets/travel_map_data.dart';

class MapDataService {
  final SupabaseClient _client;

  MapDataService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  User? get _currentUser => _client.auth.currentUser;

  // ── 유저 권한 ────────────────────────────────────────────────────────────

  /// DB에서 구매(활성화)된 지도 ID 목록을 가져온다.
  /// 로그인하지 않았거나 오류 시 빈 Set 반환.
  Future<Set<String>> fetchPurchasedMapIds() async {
    final user = _currentUser;
    if (user == null) return {};

    try {
      final res = await _client
          .from('users')
          .select('active_maps')
          .eq('auth_uid', user.id)
          .maybeSingle();

      final List active = (res?['active_maps'] as List?) ?? [];
      return active.map((e) => e.toString().toLowerCase()).toSet();
    } catch (e) {
      _log('fetchPurchasedMapIds 실패: $e');
      return {};
    }
  }

  // ── 여행 데이터 ──────────────────────────────────────────────────────────

  /// 현재 유저의 모든 여행 데이터를 맵 렌더링용으로 정리해서 반환.
  /// 로그인하지 않았거나 오류 시 빈 데이터 반환.
  Future<TravelMapData> fetchTravelMapData() async {
    final user = _currentUser;
    if (user == null) return TravelMapData.empty();

    try {
      final rows = await _client
          .from('travels')
          .select('country_code, region_name, is_completed, travel_type')
          .eq('user_id', user.id);

      return TravelMapData.fromRows(rows as List);
    } catch (e) {
      _log('fetchTravelMapData 실패: $e');
      return TravelMapData.empty();
    }
  }

  // ── 팝업 데이터 ──────────────────────────────────────────────────────────

  /// 국가(+선택적으로 지역)에 해당하는 완료된 여행의 이미지 URL과 AI 요약을 반환.
  /// 결과가 없으면 null 반환.
  Future<({String imageUrl, String summary})?> fetchPopupData({
    required String countryCode,
    String? regionName, // 상세 지도 보유 시 전달
  }) async {
    final user = _currentUser;
    if (user == null) return null;

    try {
      var query = _client
          .from('travels')
          .select('map_image_url, ai_cover_summary')
          .eq('user_id', user.id)
          .eq('country_code', countryCode)
          .eq('is_completed', true);

      if (regionName != null) query = query.eq('region_name', regionName);

      final results = await query
          .order('created_at', ascending: false)
          .limit(1);

      if ((results as List).isEmpty) return null;

      final res = results.first;
      final rawSummary = (res['ai_cover_summary'] ?? '').toString();
      final imageUrl = res['map_image_url']?.toString() ?? '';

      return (
        imageUrl: imageUrl,
        summary: rawSummary.replaceAll('**', '').trim(),
      );
    } catch (e) {
      _log('fetchPopupData 실패: $e');
      return null;
    }
  }

  // ── 마지막 여행지 ────────────────────────────────────────────────────────

  /// 가장 최근 여행의 좌표를 반환. 없으면 null.
  Future<({double lat, double lng})?> fetchLastTravelCoordinates() async {
    final user = _currentUser;
    if (user == null) return null;

    try {
      final res = await _client
          .from('travels')
          .select('region_lat, region_lng, country_lat, country_lng')
          .eq('user_id', user.id)
          .order('end_date', ascending: false)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res == null) return null;

      final lat = (res['region_lat'] as num? ?? res['country_lat'] as num?)
          ?.toDouble();
      final lng = (res['region_lng'] as num? ?? res['country_lng'] as num?)
          ?.toDouble();

      if (lat == null || lng == null) return null;
      return (lat: lat, lng: lng);
    } catch (e) {
      _log('fetchLastTravelCoordinates 실패: $e');
      return null;
    }
  }

  // ── 내부 유틸 ────────────────────────────────────────────────────────────

  void _log(String msg) {
    assert(() {
      // ignore: avoid_print
      print('⚠️ [MapDataService] $msg');
      return true;
    }());
  }
}
