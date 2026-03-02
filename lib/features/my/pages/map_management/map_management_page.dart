import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/services/payment_service.dart';
import 'package:travel_memoir/core/widgets/popup/app_toast.dart';

import 'package:flutter_svg/flutter_svg.dart';

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
        'icon': 'assets/icons/ico_map_world.svg', // ✅ SVG 경로로 변경
        'isFixed': true,
        'isAvailable': true,
      },
      {
        'id': 'ko',
        'name': 'korea_map',
        'icon': 'assets/icons/ico_map_ko.svg', // ✅ SVG 경로로 변경
        'isFixed': false,
        'isAvailable': true,
      },
      {
        'id': 'us',
        'name': 'usa_map',
        'icon': 'assets/icons/ico_map_us.svg', // ✅ SVG 경로로 변경
        'isFixed': false, // ✅ 수정: true → false
        'isAvailable': true,
      },
      {
        'id': 'jp',
        'name': 'japan_map',
        'icon': 'assets/icons/ico_map_jp.svg', // ✅ SVG 경로로 변경
        'isFixed': false,
        'isAvailable': false,
      },
      {
        'id': 'it',
        'name': 'italy_map',
        'icon': 'assets/icons/ico_map_it.svg', // ✅ SVG 경로로 변경
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
      backgroundColor: const Color(0xFFF6F6F6),
      body: SafeArea(
        child: SingleChildScrollView(
          // 디자인: 첫 번째 소스와 동일한 여백값 적용
          padding: const EdgeInsets.fromLTRB(27, 18, 27, 27),
          child: Column(
            children: [
              // ❶ [디자인] 커스텀 상단바 (제목 중앙, 복원 버튼 우측)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 제목: 중앙 정렬
                    Text(
                      'map_settings'.tr(),
                      style: AppTextStyles.pageTitle.copyWith(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textColor01,
                      ),
                    ),
                    // 복원 버튼: 우측 끝 정렬
                    Positioned(
                      right: 0,
                      child: TextButton(
                        onPressed: _handleRestore, // 로직: 기존 복원 함수 그대로 사용
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                        ),
                        child: Text(
                          'restore'.tr(),
                          style: const TextStyle(
                            color: Color(0xFF289AEB),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: Color(0xFF289AEB),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),

              // ❷ [로직] 기존 FutureBuilder 로직 100% 동일하게 유지
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snapshot) {
                  // 기존 로직: 로딩 중 처리
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      _localMapList == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  // 기존 로직: 데이터 할당
                  if (snapshot.hasData && _localMapList == null) {
                    _localMapList = List.from(snapshot.data!);
                  }
                  // 기존 로직: 빈 화면 처리
                  if (_localMapList == null) return const SizedBox.shrink();

                  // 디자인: 리스트를 Column으로 배치 (스크롤 꼬임 방지)
                  return Column(
                    children: List.generate(_localMapList!.length, (index) {
                      return _MapItemTile(
                        map: _localMapList![index],
                        onToggle: () => _handleToggle(index), // 기존 로직 연결
                        onPurchase: () => _handleMapPurchase(
                          _localMapList![index]['id'],
                        ), // 기존 로직 연결
                      );
                    }),
                  );
                },
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.only(bottom: 13),
      child: Opacity(
        opacity: isAvailable ? 1.0 : 0.6,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isPurchased
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Theme(
            // ❶ ListTile의 클릭 효과를 여기서 죽입니다.
            data: Theme.of(context).copyWith(
              splashColor: Colors.transparent, // 물결 제거
              highlightColor: Colors.transparent, // 하이라이트 제거
              hoverColor: Colors.transparent, // 호버 제거
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(22, 10, 18, 10),
              horizontalTitleGap: 12,

              leading: SvgPicture.asset(map['icon'], width: 25, height: 25),
              title: Text(
                map['name'].toString().tr(),
                style: AppTextStyles.sectionTitle.copyWith(
                  fontSize: 15,
                  color: AppColors.textColor01,
                  fontWeight: FontWeight.w600,
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
      // ❶ '준비중' 텍스트 좌우 10px 여백 추가
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(
          'coming_soon'.tr(),
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
      );
    }

    if (!isPurchased) {
      // ❷ '구매하기' 버튼 좌우 10px 여백 추가
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(
          'BUY'.tr(),
          style: const TextStyle(
            color: Color(0xFF289AEB),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
            decorationColor: Color(0xFF289AEB),
          ),
        ),
      );
    }
    if (isFixed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          'active_label'.tr(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xffADADAD),
          ),
        ),
      );
    }
    return Transform.scale(
      scale: 0.9, // ✅ 1.0보다 작으면 작아지고, 크면 커집니다. (0.7~0.8 추천)
      child: CupertinoSwitch(
        value: isActive,
        activeColor: AppColors.travelingBlue,
        onChanged: (_) => onToggle(),
      ),
    );
  }
}
