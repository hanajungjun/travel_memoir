import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:travel_memoir/models/country_model.dart';
import 'package:travel_memoir/core/constants/korea/korea_region.dart';
import 'package:travel_memoir/services/image_upload_service.dart';

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
    final travel = await _supabase
        .from('travels')
        .insert({
          'user_id': userId,
          'travel_type': 'domestic',

          'country_code': 'KR',
          'country_name': '대한민국',
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
    final travel = await _supabase
        .from('travels')
        .insert({
          'user_id': userId,
          'travel_type': 'overseas',

          'country_code': country.code,
          'country_name': country.displayName(),
          'continent': country.continent,

          'country_lat': country.lat,
          'country_lng': country.lng,

          'start_date': startDate.toIso8601String().substring(0, 10),
          'end_date': endDate.toIso8601String().substring(0, 10),

          'is_completed': false,
        })
        .select()
        .single();

    return travel;
  }

  // ============================
  // ❌ 여행 삭제
  // ============================
  static Future<void> deleteTravel(String travelId) async {
    final supabase = Supabase.instance.client;

    final res = await supabase.functions.invoke(
      'delete_travel',
      body: {'travel_id': travelId},
    );

    if (res.data == null || res.data['ok'] != true) {
      throw Exception('delete_travel failed: ${res.data}');
    }
  }
}
