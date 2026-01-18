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
    final res = await Supabase.instance.client
        .from('users')
        .select('active_maps')
        .eq('auth_uid', _userId)
        .maybeSingle();

    final List<dynamic> activeIds = res?['active_maps'] ?? ['ko', 'world'];

    final List<Map<String, dynamic>> baseMaps = [
      {'id': 'world', 'name': 'world_map', 'icon': '🌎', 'isPurchased': true},
      {'id': 'ko', 'name': 'korea_map', 'icon': '🇰🇷', 'isPurchased': true},
      {'id': 'us', 'name': 'usa_map', 'icon': '🇺🇸', 'isPurchased': true},
      {'id': 'jp', 'name': 'japan_map', 'icon': '🇯🇵', 'isPurchased': false},
      {'id': 'it', 'name': 'italy_map', 'icon': '🇮🇹', 'isPurchased': false},
    ];

    List<Map<String, dynamic>> sortedList = [];

    for (var id in activeIds) {
      final map = baseMaps.firstWhere((m) => m['id'] == id, orElse: () => {});
      if (map.isNotEmpty) {
        map['isActive'] = true;
        sortedList.add(map);
      }
    }

    for (var map in baseMaps) {
      if (!activeIds.contains(map['id'])) {
        map['isActive'] = false;
        sortedList.add(map);
      }
    }

    return sortedList;
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
    int activeCount = _localMapList!.where((m) => m['isActive'] == true).length;
    bool currentState = _localMapList![index]['isActive'];

    setState(() {
      if (currentState && activeCount <= 1) {
        _showSnackBar('min_map_alert'.tr());
        return;
      }
      if (!currentState && activeCount >= 2) {
        _showSnackBar('max_map_alert'.tr());
        return;
      }
      _localMapList![index]['isActive'] = !currentState;
    });

    _syncToDb();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
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

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: const Color(0xFFF8F9FA),
                centerTitle: true,
                title: Text(
                  'map_settings'.tr(),
                  style: AppTextStyles.sectionTitle,
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              /// ✅ 도움말 문구
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Text(
                    '지도를 꾹 눌러서 순서를 변경해주세요',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                sliver: SliverReorderableList(
                  itemCount: _localMapList!.length,
                  onReorder: (oldIndex, newIndex) {
                    if (oldIndex < newIndex) newIndex -= 1;

                    final oldItem = _localMapList![oldIndex];
                    final newItem = _localMapList![newIndex];

                    // ❌ 구매 맵끼리만 이동 허용
                    if (!(oldItem['isPurchased'] == true &&
                        newItem['isPurchased'] == true)) {
                      _showSnackBar('구매한 지도만 순서 변경이 가능합니다');
                      return;
                    }

                    setState(() {
                      final item = _localMapList!.removeAt(oldIndex);
                      _localMapList!.insert(newIndex, item);
                    });

                    _syncToDb();
                  },
                  itemBuilder: (context, index) {
                    final map = _localMapList![index];

                    return _MapItemTile(
                      key: ValueKey(map['id']),
                      map: map,
                      index: index,
                      onToggle: () => _handleToggle(index),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MapItemTile extends StatelessWidget {
  final Map<String, dynamic> map;
  final VoidCallback onToggle;
  final int index;

  const _MapItemTile({
    super.key,
    required this.map,
    required this.onToggle,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPurchased = map['isPurchased'] ?? false;
    final bool isActive = map['isActive'] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: isPurchased ? Colors.white : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 10,
            ),

            /// ✅ 구매 맵만 드래그 가능
            leading: isPurchased
                ? ReorderableDragStartListener(
                    index: index,
                    child: Text(
                      map['icon'],
                      style: const TextStyle(fontSize: 32),
                    ),
                  )
                : Text(map['icon'], style: const TextStyle(fontSize: 32)),

            title: Text(
              map['name'].toString().tr(),
              style: AppTextStyles.sectionTitle.copyWith(
                fontSize: 18,
                color: isPurchased ? Colors.black87 : Colors.grey,
              ),
            ),

            trailing: isPurchased
                ? CupertinoSwitch(
                    value: isActive,
                    activeColor: AppColors.travelingBlue,
                    onChanged: (_) => onToggle(),
                  )
                : const Icon(Icons.shopping_cart_outlined, color: Colors.blue),
          ),
        ),
      ),
    );
  }
}
