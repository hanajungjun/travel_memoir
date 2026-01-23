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
