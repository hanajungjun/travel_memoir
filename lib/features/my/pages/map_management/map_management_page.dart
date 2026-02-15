import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/services/payment_service.dart';
import 'package:travel_memoir/core/widgets/popup/app_toast.dart';

class MapManagementPage extends StatefulWidget {
  const MapManagementPage({super.key});

  @override
  State<MapManagementPage> createState() => _MapManagementPageState();
}

class _MapManagementPageState extends State<MapManagementPage> {
  final String _userId = Supabase.instance.client.auth.currentUser!.id;
  late Future<List<Map<String, dynamic>>> _future;
  List<Map<String, dynamic>>? _localMapList;
  List<Package> _mapPackages = [];

  @override
  void initState() {
    super.initState();
    _refresh();
    _loadStoreProducts();
  }

  Future<void> _loadStoreProducts() async {
    final offerings = await PaymentService.getOfferings();
    if (offerings?.current != null) {
      setState(() {
        _mapPackages = offerings!.current!.availablePackages
            .where(
              (p) => p.storeProduct.identifier.toLowerCase().contains('map'),
            )
            .toList();
      });
    }
  }

  Future<List<Map<String, dynamic>>> _getMapData() async {
    final res = await Supabase.instance.client
        .from('users')
        .select('active_maps, owned_maps')
        .eq('auth_uid', _userId)
        .maybeSingle();

    final List<dynamic> activeIds = res?['active_maps'] ?? ['ko', 'world'];
    final List<dynamic> ownedIds = res?['owned_maps'] ?? ['ko', 'world'];

    final List<Map<String, dynamic>> baseMaps = [
      {
        'id': 'world',
        'name': 'world_map',
        'icon': '🌎',
        'isFixed': true,
        'isAvailable': true,
      },
      {
        'id': 'ko',
        'name': 'korea_map',
        'icon': '🇰🇷',
        'isFixed': false,
        'isAvailable': true,
      },
      {
        'id': 'us',
        'name': 'usa_map',
        'icon': '🇺🇸',
        'isFixed': false, // ✅ 수정: true → false
        'isAvailable': true,
      },
      {
        'id': 'jp',
        'name': 'japan_map',
        'icon': '🇯🇵',
        'isFixed': false,
        'isAvailable': false,
      },
      {
        'id': 'it',
        'name': 'italy_map',
        'icon': '🇮🇹',
        'isFixed': false,
        'isAvailable': false,
      },
    ];

    return baseMaps.map((map) {
      final String id = map['id'];
      map['isPurchased'] = ownedIds.contains(id);
      map['isActive'] = activeIds.contains(id) || (id == 'world');
      return map;
    }).toList();
  }

  void _refresh() {
    setState(() {
      _future = _getMapData();
      _localMapList = null;
    });
  }

  Future<void> _handleRestore() async {
    AppToast.show(context, 'restore'.tr());
    final success = await PaymentService.restorePurchases();
    if (success) {
      _refresh();
      AppToast.show(context, 'restore_success_msg'.tr());
    } else {
      AppToast.error(context, 'restore_fail_msg'.tr());
    }
  }

  Future<void> _handleMapPurchase(String mapId) async {
    //print('🗺️ 구매 시도: $mapId');
    print(
      '📦 패키지 목록: ${_mapPackages.map((p) => p.storeProduct.identifier).toList()}',
    );

    try {
      if (_mapPackages.isEmpty) {
        //print('❌ 패키지 없음!');
        return;
      }

      String targetIdSnippet = mapId == 'us' ? 'usa' : mapId;
      //print('🔍 찾는 키워드: $targetIdSnippet');

      final package = _mapPackages.firstWhere(
        (p) =>
            p.storeProduct.identifier.toLowerCase().contains(targetIdSnippet),
      );

      //print('✅ 매칭된 패키지: ${package.storeProduct.identifier}');

      final success = await PaymentService.purchasePackage(package);
      if (success) _refresh();
    } catch (e) {
      //print('💥 에러: $e');
      AppToast.error(context, 'no_products'.tr(args: [mapId]));
    }
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
        actions: [
          TextButton(
            onPressed: _handleRestore,
            child: Text(
              'restore'.tr(),
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
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
              return _MapItemTile(
                map: _localMapList![index],
                onToggle: () => _handleToggle(index),
                onPurchase: () =>
                    _handleMapPurchase(_localMapList![index]['id']),
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
  final VoidCallback onPurchase;

  const _MapItemTile({
    required this.map,
    required this.onToggle,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    final bool isAvailable = map['isAvailable'] ?? true;
    final bool isPurchased = map['isPurchased'] ?? false;
    final bool isActive = map['isActive'] ?? false;
    final bool isFixed = map['isFixed'] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Opacity(
        opacity: isAvailable ? 1.0 : 0.6,
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
            trailing: _buildTrailing(
              isAvailable,
              isPurchased,
              isActive,
              isFixed,
            ),
            onTap: (!isAvailable || isPurchased) ? null : onPurchase,
          ),
        ),
      ),
    );
  }

  Widget _buildTrailing(
    bool isAvailable,
    bool isPurchased,
    bool isActive,
    bool isFixed,
  ) {
    if (!isAvailable) {
      return Text(
        'coming_soon'.tr(),
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
    }
    if (!isPurchased) {
      return const Icon(Icons.shopping_cart_outlined, color: Colors.blue);
    }
    if (isFixed) {
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
