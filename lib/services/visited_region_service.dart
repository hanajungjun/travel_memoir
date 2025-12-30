import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class VisitedRegionService {
  static final _supabase = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> getVisitedRegionsAll({
    required String userId,
  }) async {
    debugPrint('🧭 [VISITED] load visited_regions_view (user=$userId)');

    final rows = await _supabase
        .from('visited_regions_view')
        .select('type, sido_cd, sgg_cd')
        .eq('user_id', userId);

    debugPrint('🧭 [VISITED] rows = $rows');

    return List<Map<String, dynamic>>.from(rows);
  }
}
