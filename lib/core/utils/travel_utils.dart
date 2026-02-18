import 'package:flutter/material.dart';

/// 방문한 나라/지역 수에 따른 배지 정보를 반환합니다.
Map<String, dynamic> getBadge(int count) {
  if (count >= 80) {
    return {
      'title_key': 'badge_legend_traveler',
      'color': Colors.black,
      'icon': Icons.workspace_premium,
    };
  }
  if (count >= 70) {
    return {
      'title_key': 'badge_earth_conqueror',
      'color': Colors.deepPurple,
      'icon': Icons.public,
    };
  }
  if (count >= 60) {
    return {
      'title_key': 'badge_global_nomad',
      'color': Colors.indigo,
      'icon': Icons.language,
    };
  }
  if (count >= 50) {
    return {
      'title_key': 'badge_world_explorer',
      'color': Colors.blue,
      'icon': Icons.travel_explore,
    };
  }
  if (count >= 40) {
    return {
      'title_key': 'badge_border_crosser',
      'color': Colors.lightBlue,
      'icon': Icons.flight_takeoff,
    };
  }
  if (count >= 30) {
    return {
      'title_key': 'badge_pro_wanderer',
      'color': Colors.blueAccent,
      'icon': Icons.explore,
    };
  }
  if (count >= 20) {
    return {
      'title_key': 'badge_road_tripper',
      'color': Colors.teal,
      'icon': Icons.directions_car,
    };
  }
  if (count >= 10) {
    return {
      'title_key': 'badge_first_steps',
      'color': Colors.lightGreen,
      'icon': Icons.directions_walk,
    };
  }
  if (count >= 1) {
    return {
      'title_key': 'badge_newbie_traveler',
      'color': Colors.green,
      'icon': Icons.hiking,
    };
  }
  return {
    'title_key': 'badge_preparing_adventure',
    'color': Colors.grey,
    'icon': Icons.map,
  };
}

class TravelUtils {
  static const Map<String, List<String>> majorCityMapping = {
    "41110": ["41111", "41113", "41115", "41117"],
    "41130": ["41131", "41133", "41135"],
    "41170": ["41171", "41173"],
    "41270": ["41271", "41273"],
    "41280": ["41281", "41285", "41287"],
    "41460": ["41461", "41463", "41465"],
    "43110": ["43111", "43112", "43113", "43114"],
    "44130": ["44131", "44133"],
    "45110": ["45111", "45113"],
    "47110": ["47111", "47113"],
    "48120": ["48121", "48123", "48125", "48127", "48129"],
    "11000": [
      "11110",
      "11140",
      "11170",
      "11200",
      "11215",
      "11230",
      "11260",
      "11290",
      "11305",
      "11320",
      "11350",
      "11380",
      "11410",
      "11440",
      "11470",
      "11500",
      "11530",
      "11545",
      "11560",
      "11590",
      "11620",
      "11650",
      "11680",
      "11710",
      "11740",
    ],
    "26000": [
      "26110",
      "26140",
      "26170",
      "26200",
      "26230",
      "26260",
      "26290",
      "26320",
      "26350",
      "26380",
      "26410",
      "26440",
      "26470",
      "26500",
      "26530",
      "26710",
    ],
    "27000": [
      "27110",
      "27140",
      "27170",
      "27200",
      "27230",
      "27260",
      "27290",
      "27710",
      "27720",
    ],
    "28000": [
      "28110",
      "28140",
      "28170",
      "28185",
      "28200",
      "28237",
      "28245",
      "28260",
      "28710",
      "28720",
    ],
    "29000": ["29110", "29140", "29155", "29170", "29200"],
    "30000": ["30110", "30140", "30170", "30200", "30230"],
    "31000": ["31110", "31140", "31170", "31200", "31710"],
    "36110": ["36110"],
  };
}
