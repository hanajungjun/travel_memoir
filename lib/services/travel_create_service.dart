import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:travel_memoir/models/country_model.dart';
import 'package:travel_memoir/core/constants/korea/korea_region.dart';
import 'package:travel_memoir/core/constants/korea/sgg_code_map.dart';
import 'package:travel_memoir/storage_paths.dart'; // 🎯 경로 관리 클래스 임포트

class TravelCreateService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // ============================
  // 🇰🇷 국내 여행 생성
  // ============================
  static Future<Map<String, dynamic>> createDomesticTravel({
    required String userId,
    required KoreaRegion region,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final String regionKey = region.id;

    debugPrint("🚀 [Domestic] regionKey: $regionKey");

    // ✅ StoragePaths를 통해 한국 지도 버킷 URL 획득
    final String mapImageUrl = StoragePaths.domesticMap(regionKey);

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
          'map_image_url': mapImageUrl, // 🎯 주입
          'province': region.province,
          'region_lat': region.lat,
          'region_lng': region.lng,
          'start_date': startDate.toIso8601String().substring(0, 10),
          'end_date': endDate.toIso8601String().substring(0, 10),
          'is_completed': false,
        })
        .select()
        .single();

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
    final String countryCode = country.code.toUpperCase();

    // ✅ StoragePaths를 통해 글로벌 지도 버킷 URL 획득
    final String mapImageUrl = StoragePaths.globalMap(countryCode);

    final travel = await _supabase
        .from('travels')
        .insert({
          'user_id': userId,
          'travel_type': 'overseas',
          'country_code': countryCode,
          'country_name_ko': country.nameKo,
          'country_name_en': country.nameEn,
          'continent': country.continent,
          'country_lat': country.lat,
          'country_lng': country.lng,
          'region_key': countryCode,
          'map_image_url': mapImageUrl, // 🎯 주입
          'start_date': startDate.toIso8601String().substring(0, 10),
          'end_date': endDate.toIso8601String().substring(0, 10),
          'is_completed': false,
        })
        .select()
        .single();

    await _createEmptyDays(
      travelId: travel['id'],
      startDate: startDate,
      endDate: endDate,
    );

    return travel;
  }

  // ============================
  // 🇺🇸 미국 여행 생성 (최종 수정본)
  // ============================
  static Future<Map<String, dynamic>> createUSATravel({
    required String userId,
    required CountryModel country,
    required String regionKey, // 🎯 이미지 경로 및 DB 로직용 키 (예: Arizona)
    required String stateName, // 🎯 화면 표시용 이름 (예: Arizona)
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final String countryCode = country.code.toUpperCase();

    // 1️⃣ StoragePaths를 통해 정확한 주(State) 지도 URL 생성
    // 결과: .../usa_map_image/Arizona.png
    final String mapImageUrl = StoragePaths.usaMap(regionKey);

    debugPrint("🇺🇸 [미국 여행 생성] regionKey: $regionKey, stateName: $stateName");

    // 2️⃣ 여행 기록 인서트
    final travel = await _supabase
        .from('travels')
        .insert({
          'user_id': userId,
          'travel_type': 'usa',
          'country_code': countryCode,
          'country_name_ko': country.nameKo,
          'country_name_en': country.nameEn,
          'region_name': stateName, // 화면에 보여줄 이름
          'region_key': regionKey, // 🎯 이미지 매칭 및 로직용 키
          'continent': country.continent,
          'country_lat': country.lat,
          'country_lng': country.lng,
          'map_image_url': mapImageUrl, // 🎯 생성된 URL 주입
          'start_date': startDate.toIso8601String().substring(0, 10),
          'end_date': endDate.toIso8601String().substring(0, 10),
          'is_completed': false,
        })
        .select()
        .single();

    // 3️⃣ 빈 일기 칸 선발행
    await _createEmptyDays(
      travelId: travel['id'],
      startDate: startDate,
      endDate: endDate,
    );

    return travel;
  }

  // ============================
  // 📦 [헬퍼] 빈 일기 로우 배치 인서트 (기존 유지)
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

    await _supabase.from('travel_days').insert(batchData);
  }

  // ============================
  // ❌ 여행 삭제 (기존 유지)
  // ============================
  static Future<void> deleteTravel(String travelId) async {
    final res = await _supabase.functions.invoke(
      'delete_travel',
      body: {'travel_id': travelId},
    );

    if (res.data == null || res.data['ok'] != true) {
      throw Exception('delete_travel failed: ${res.data}');
    }
  }
}
