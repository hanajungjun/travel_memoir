import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/services/payment_service.dart';

class MapManagementPage extends StatefulWidget {
  const MapManagementPage({super.key});

  @override
  State<MapManagementPage> createState() => _MapManagementPageState();
}

class _MapManagementPageState extends State<MapManagementPage> {
  final String _userId = Supabase.instance.client.auth.currentUser!.id;
  late Future<List<Map<String, dynamic>>> _future;
  List<Map<String, dynamic>>? _localMapList;
  List<Package> _mapPackages = []; // 스토어 실제 상품 정보

  @override
  void initState() {
    super.initState();
    _refresh();
    _loadStoreProducts();
  }

  // RevenueCat에서 실제 상품 로드
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
        .select('active_maps')
        .eq('auth_uid', _userId)
        .maybeSingle();

    final List<dynamic> activeIds = res?['active_maps'] ?? ['ko', 'world'];

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
      bool isPurchased =
          (id == 'world' || id == 'ko') || activeIds.contains(id);

      // 활성화 상태: world는 기본, 나머지는 activeIds에 포함 여부
      bool isActive =
          activeIds.contains(id) || (id == 'world' && !activeIds.contains(id));

      map['isPurchased'] = isPurchased;
      map['isActive'] = isActive;
      resultList.add(map);
    }

    // 정렬: 구매한 것 위로
    resultList.sort((a, b) {
      if (a['isPurchased'] == b['isPurchased']) return 0;
      return a['isPurchased'] ? -1 : 1;
    });

    return resultList;
  }

  void _refresh() {
    setState(() {
      _future = _getMapData();
      _localMapList = null;
    });
  }

  // 지도 결제 핸들러
  Future<void> _handleMapPurchase(String mapId) async {
    try {
      // 🎯 국가 코드(db id)를 스토어 등록 ID 키워드와 매칭
      String targetIdSnippet = mapId;
      if (mapId == 'us') {
        targetIdSnippet = 'usa';
      } else if (mapId == 'jp') {
        targetIdSnippet = 'japan'; // 스토어 ID가 ...japan_map 일 때
      } else if (mapId == 'it') {
        targetIdSnippet = 'italy'; // 스토어 ID가 ...italy_map 일 때
      }

      // 🔍 해당 키워드가 포함된 패키지 찾기
      final package = _mapPackages.firstWhere(
        (p) =>
            p.storeProduct.identifier.toLowerCase().contains(targetIdSnippet),
      );

      debugPrint("💳 지도 결제 시도: ${package.storeProduct.identifier}");

      final success = await PaymentService.purchasePackage(package);
      if (success) {
        _refresh(); // 구매 성공 시 DB에서 active_maps 다시 읽어와서 UI 갱신 (정렬 포함)
      }
    } catch (e) {
      // 패키지를 못 찾았을 때의 예외 처리
      debugPrint("❌ 지도 구매 패키지를 찾을 수 없음 (mapId: $mapId): $e");

      // 사용자에게 알림을 주고 싶다면 SnackBar 추가
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('상품 정보를 불러올 수 없습니다. ($mapId)')));
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
                onPurchase: () => _handleMapPurchase(map['id']), // 구매 기능 연결
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
          onTap: isPurchased ? null : onPurchase, // 미구매 지도는 클릭 시 구매
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
