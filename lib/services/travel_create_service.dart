import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:travel_memoir/models/country_model.dart';
import 'package:travel_memoir/core/constants/korea/korea_region.dart';
import 'package:travel_memoir/core/constants/korea/sgg_code_map.dart';

class TravelCreateService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // 🚀 [설정] 프로젝트 ID를 실제 수파베이스 프로젝트 ID로 꼭 변경하세요!
  static const String _supabaseProjectId = 'tpgfnqbtioxmvartxjii';
  static const String _storageBaseUrl =
      'https://$_supabaseProjectId.supabase.co/storage/v1/object/public/map_images';

  // ============================
  // 🇰🇷 국내 여행 생성
  // ============================
  static Future<Map<String, dynamic>> createDomesticTravel({
    required String userId,
    required KoreaRegion region,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // 1️⃣ region_key 추출 (예: KR_GG_YEOJU -> YEOJU)
    //final String regionKey = region.id.split('_').last;
    final String regionKey = region.id; // ✅ 이제 KR_GB_POHANG 전체가 들어감

    debugPrint("🚀뭐지 포항뭐야 [regionKey]: $regionKey");

    // 2️⃣ 통합된 map_images 버킷 경로 생성
    final String mapImageUrl = '$_storageBaseUrl/$regionKey.png';

    // 3️⃣ 여행 기록 인서트
    final travel = await _supabase
        .from('travels')
        .insert({
          'user_id': userId,
          'travel_type': 'domestic',
          'country_code': 'KR',
          'country_name_ko': '대한민국',
          'continent': 'Asia',
          'country_lat': 35.9078,
          'country_lng': 127.7669,
          'region_id': region.id,
          'region_name': region.name,
          'region_key': regionKey,
          'map_image_url': mapImageUrl,
          'province': region.province,
          'region_lat': region.lat,
          'region_lng': region.lng,
          'start_date': startDate.toIso8601String().substring(0, 10),
          'end_date': endDate.toIso8601String().substring(0, 10),
          'is_completed': false,
        })
        .select()
        .single();

    // 4️⃣ 지도용 방문 지역 즉시 upsert (국내 지도 연동용)
    final code = SggCodeMap.fromRegionId(region.id);
    await _supabase.from('domestic_travel_regions').upsert({
      'travel_id': travel['id'],
      'user_id': userId,
      'region_id': region.id,
      'map_region_id': region.id,
      'map_region_type': code.type,
      'sido_cd': code.sidoCd,
      'sgg_cd': code.sggCd,
      'is_completed': false,
    }, onConflict: 'user_id,region_id');

    // 5️⃣ 빈 일기 칸 선발행
    await _createEmptyDays(
      travelId: travel['id'],
      startDate: startDate,
      endDate: endDate,
    );

    return travel;
  }

  // ============================
  // 🌍 해외 여행 생성
  // ============================
  static Future<Map<String, dynamic>> createOverseasTravel({
    required String userId,
    required CountryModel country,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // 1️⃣ 국가 코드를 region_key로 활용 (대문자 통일)
    final String countryCode = country.code.toUpperCase();

    // 2️⃣ 통합된 map_images 버킷 경로 생성
    final String mapImageUrl = '$_storageBaseUrl/$countryCode.png';

    // 3️⃣ 여행 기록 인서트
    final travel = await _supabase
        .from('travels')
        .insert({
          'user_id': userId,
          'travel_type': 'overseas',
          'country_code': countryCode,
          'country_name_ko': country.nameKo,
          'country_name_en': country.nameEn,
          'continent': country.continent,
          'country_lat': country.lat, // 📍 해외 지도 포커스용 좌표
          'country_lng': country.lng,
          'region_key': countryCode, // ✅ 목록 UI 영어 이름 연동용
          'map_image_url': mapImageUrl, // ✅ 해외 지도 미니어처 이미지
          'start_date': startDate.toIso8601String().substring(0, 10),
          'end_date': endDate.toIso8601String().substring(0, 10),
          'is_completed': false,
        })
        .select()
        .single();

    // 4️⃣ 빈 일기 칸 선발행
    await _createEmptyDays(
      travelId: travel['id'],
      startDate: startDate,
      endDate: endDate,
    );

    return travel;
  }

  // ============================
  // 📦 [헬퍼] 빈 일기 로우 배치 인서트
  // ============================
  static Future<void> _createEmptyDays({
    required String travelId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final int totalDays = endDate.difference(startDate).inDays + 1;
    List<Map<String, dynamic>> batchData = [];

    for (int i = 0; i < totalDays; i++) {
      final currentDate = startDate.add(Duration(days: i));
      batchData.add({
        'travel_id': travelId,
        'day_index': i + 1,
        'date': currentDate.toIso8601String().substring(0, 10),
        'text': '',
        'photo_urls': [],
        'is_completed': false,
      });
    }

    // 일괄 생성으로 성능 최적화
    await _supabase.from('travel_days').insert(batchData);
  }

  // ============================
  // ❌ 여행 삭제
  // ============================
  static Future<void> deleteTravel(String travelId) async {
    // 수파베이스 엣지 펑션을 통해 관련 데이터(일기, 이미지 등) 일괄 삭제
    final res = await _supabase.functions.invoke(
      'delete_travel',
      body: {'travel_id': travelId},
    );

    if (res.data == null || res.data['ok'] != true) {
      throw Exception('delete_travel failed: ${res.data}');
    }
  }
}
