import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class MapManagementPage extends StatefulWidget {
  const MapManagementPage({super.key});

  @override
  State<MapManagementPage> createState() => _MapManagementPageState();
}

class _MapManagementPageState extends State<MapManagementPage> {
  final String _userId = Supabase.instance.client.auth.currentUser!.id;
  late Future<List<Map<String, dynamic>>> _future;
  List<Map<String, dynamic>>? _localMapList;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<List<Map<String, dynamic>>> _getMapData() async {
    // 1. 유저의 활성화 목록 가져오기 (active_maps)
    final res = await Supabase.instance.client
        .from('users')
        .select('active_maps')
        .eq('auth_uid', _userId)
        .maybeSingle();

    final List<dynamic> activeIds = res?['active_maps'] ?? ['ko', 'world'];

    // 2. 기본 맵 정의
    final List<Map<String, dynamic>> baseMaps = [
      {'id': 'world', 'name': 'world_map', 'icon': '🌎', 'isFixed': true},
      {'id': 'us', 'name': 'usa_map', 'icon': '🇺🇸', 'isFixed': true},
      {'id': 'ko', 'name': 'korea_map', 'icon': '🇰🇷', 'isFixed': false},
      {'id': 'jp', 'name': 'japan_map', 'icon': '🇯🇵', 'isFixed': false},
      {'id': 'it', 'name': 'italy_map', 'icon': '🇮🇹', 'isFixed': false},
    ];

    List<Map<String, dynamic>> resultList = [];
    for (var map in baseMaps) {
      final String id = map['id'];

      // 한국(ko)과 세계지도(world)는 무조건 '구매됨' 상태
      bool isPurchased =
          (id == 'world' || id == 'ko') || activeIds.contains(id);

      // 활성화(isActive) 상태 결정
      bool isActive = false;
      if (id == 'world') {
        isActive = true;
      } else if (id == 'us') {
        isActive = activeIds.contains('us');
      } else {
        isActive = activeIds.contains(id);
      }

      map['isPurchased'] = isPurchased;
      map['isActive'] = isActive;
      resultList.add(map);
    }

    // ✅ [추가] 정렬 로직: 구매한 지도를 위로, 구매하지 않은 지도를 아래로 정렬
    resultList.sort((a, b) {
      if (a['isPurchased'] == b['isPurchased']) return 0;
      return a['isPurchased'] ? -1 : 1; // 구매한 것이 위(-1)로, 아니면 아래(1)로
    });

    return resultList;
  }

  void _refresh() {
    setState(() {
      _future = _getMapData();
      _localMapList = null;
    });
  }

  Future<void> _syncToDb() async {
    if (_localMapList == null) return;

    final activeIds = _localMapList!
        .where((m) => m['isActive'] == true)
        .map((m) => m['id'].toString())
        .toList();

    await Supabase.instance.client
        .from('users')
        .update({'active_maps': activeIds})
        .eq('auth_uid', _userId);
  }

  void _handleToggle(int index) {
    final map = _localMapList![index];
    if (map['isFixed'] == true && map['isActive'] == true) return;

    setState(() {
      map['isActive'] = !map['isActive'];
    });

    _syncToDb();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        centerTitle: true,
        title: Text('map_settings'.tr(), style: AppTextStyles.sectionTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _localMapList == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasData && _localMapList == null) {
            _localMapList = List.from(snapshot.data!);
          }

          if (_localMapList == null) return const SizedBox.shrink();

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            itemCount: _localMapList!.length,
            itemBuilder: (context, index) {
              final map = _localMapList![index];
              return _MapItemTile(
                map: map,
                onToggle: () => _handleToggle(index),
              );
            },
          );
        },
      ),
    );
  }
}

class _MapItemTile extends StatelessWidget {
  final Map<String, dynamic> map;
  final VoidCallback onToggle;

  const _MapItemTile({required this.map, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final bool isPurchased = map['isPurchased'] ?? false;
    final bool isActive = map['isActive'] ?? false;
    final bool isFixed = map['isFixed'] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: isPurchased ? Colors.white : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isPurchased
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 10,
          ),
          leading: Text(map['icon'], style: const TextStyle(fontSize: 32)),
          title: Text(
            map['name'].toString().tr(),
            style: AppTextStyles.sectionTitle.copyWith(
              fontSize: 18,
              color: isPurchased ? Colors.black87 : Colors.grey,
            ),
          ),
          trailing: _buildTrailing(isPurchased, isActive, isFixed),
        ),
      ),
    );
  }

  Widget _buildTrailing(bool isPurchased, bool isActive, bool isFixed) {
    if (!isPurchased) {
      return const Icon(Icons.shopping_cart_outlined, color: Colors.blue);
    }

    if (isFixed && isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.travelingBlue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'active_label'.tr(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.travelingBlue,
          ),
        ),
      );
    }

    return CupertinoSwitch(
      value: isActive,
      activeColor: AppColors.travelingBlue,
      onChanged: (_) => onToggle(),
    );
  }
}
