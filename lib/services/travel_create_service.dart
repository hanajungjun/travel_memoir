import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:travel_memoir/models/country_model.dart';
import 'package:travel_memoir/core/constants/korea/korea_region.dart';
import 'package:travel_memoir/core/constants/korea/sgg_code_map.dart';

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
    // 1️⃣ 여행 기록 생성
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
          'province': region.province,
          'region_lat': region.lat,
          'region_lng': region.lng,
          'start_date': startDate.toIso8601String().substring(0, 10),
          'end_date': endDate.toIso8601String().substring(0, 10),
          'is_completed': false,
        })
        .select()
        .single();

    // 2️⃣ 🔥 지도용 방문 지역 즉시 upsert (미완료 = 빨강)
    final code = SggCodeMap.fromRegionId(region.id);

    await _supabase.from('domestic_travel_regions').upsert({
      'travel_id': travel['id'],
      'user_id': userId,
      'region_id': region.id,
      'map_region_id': region.id,
      'map_region_type': code.type,
      'sido_cd': code.sidoCd,
      'sgg_cd': code.sggCd,
      'is_completed': false, // 🔴 여행 시작
    }, onConflict: 'user_id,region_id');

    // 3️⃣ 🔥 빈 일기 칸 선발행
    await _createEmptyDays(
      travelId: travel['id'],
      startDate: startDate,
      endDate: endDate,
    );

    return travel;
  }

  // ============================
  // 🌍 해외 여행 생성 (지도 로직 없음)
  // ============================
  static Future<Map<String, dynamic>> createOverseasTravel({
    required String userId,
    required CountryModel country,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final travel = await _supabase
        .from('travels')
        .insert({
          'user_id': userId,
          'travel_type': 'overseas',
          'country_code': country.code,
          'country_name_ko': country.nameKo,
          'country_name_en': country.nameEn,
          'continent': country.continent,
          'country_lat': country.lat,
          'country_lng': country.lng,
          'start_date': startDate.toIso8601String().substring(0, 10),
          'end_date': endDate.toIso8601String().substring(0, 10),
          'is_completed': false,
        })
        .select()
        .single();

    // 빈 일기 생성
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

    await _supabase.from('travel_days').insert(batchData);
  }

  // ============================
  // ❌ 여행 삭제 (기존 로직 유지)
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
