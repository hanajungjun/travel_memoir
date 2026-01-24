import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- [1] 여권 애니메이션 다이얼로그 (3D 덮개 부분) ---
class PassportOpeningDialog extends StatefulWidget {
  const PassportOpeningDialog({super.key});

  @override
  State<PassportOpeningDialog> createState() => _PassportOpeningDialogState();
}

class _PassportOpeningDialogState extends State<PassportOpeningDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isOpened = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleOpen() {
    if (_isOpened) return;
    setState(() {
      _isOpened = true;
      _controller.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.88,
          height: MediaQuery.of(context).size.height * 0.75,
          child: Stack(
            children: [
              // 1. [속지] 열리면 보이는 내용물
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
                child: const MyStickerPage(),
              ),

              // 2. [표지] 3D 회전 덮개
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final double angle = _controller.value * math.pi;
                  return Transform(
                    alignment: Alignment.centerLeft,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(-angle * 0.9),
                    child: angle > (math.pi / 2)
                        ? const SizedBox.shrink()
                        : GestureDetector(
                            onTap: _toggleOpen,
                            child: _buildCoverFront(),
                          ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverFront() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A3D2F), // 대한민국 여권 초록색 감성
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(15),
          bottomRight: Radius.circular(15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(8, 8),
          ),
        ],
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.public, color: Color(0xFFE5C100), size: 80),
            SizedBox(height: 20),
            Text(
              'PASSPORT',
              style: TextStyle(
                color: Color(0xFFE5C100),
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- [2] 여권 속지 및 도장 페이지 (6개 배치 + 대형 도장 + 번짐 효과) ---
class MyStickerPage extends StatefulWidget {
  const MyStickerPage({super.key});

  @override
  State<MyStickerPage> createState() => _MyStickerPageState();
}

class _MyStickerPageState extends State<MyStickerPage> {
  final PageController _pageController = PageController();
  final SupabaseClient _supabase = Supabase.instance.client;
  late Future<Map<String, dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  // 날짜 변환 함수 (예: 24 JAN 2026)
  String _formatPassportDate(String? dateStr) {
    if (dateStr == null) return "";
    try {
      DateTime dt = DateTime.parse(dateStr);
      List<String> months = [
        'JAN',
        'FEB',
        'MAR',
        'APR',
        'MAY',
        'JUN',
        'JUL',
        'AUG',
        'SEP',
        'OCT',
        'NOV',
        'DEC',
      ];
      return "${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}";
    } catch (e) {
      return "";
    }
  }

  Future<Map<String, dynamic>> _loadData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {};
    final profile = await _supabase
        .from('users')
        .select()
        .eq('auth_uid', user.id)
        .maybeSingle();
    final visitedRows = await _supabase
        .from('visited_countries')
        .select()
        .eq('user_id', user.id);

    // 국가 리스트
    final countries = [
      {'code': 'ES', 'name': 'Spain'},
      {'code': 'FR', 'name': 'France'},
      {'code': 'JP', 'name': 'Japan'},
      {'code': 'US', 'name': 'USA'},
      {'code': 'IT', 'name': 'Italy'},
      {'code': 'DE', 'name': 'Germany'},
      {'code': 'KR', 'name': 'Korea'},
      {'code': 'VN', 'name': 'Vietnam'},
    ];

    final visitedData = {
      for (var row in (visitedRows as List)) row['country_code']: row,
    };

    return {
      'profile': profile,
      'stickers': countries.map((c) {
        final row = visitedData[c['code']];
        return {
          ...c,
          'id': row?['id'] ?? c['code'],
          'isUnlocked': row != null,
          'created_at': row?['created_at'],
          'asset': row != null
              ? _supabase.storage
                    .from('stickers')
                    .getPublicUrl('${c['code']}.png')
              : null,
        };
      }).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF4F1E1), // 여권 속지 특유의 미색 배경
      child: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final profile = snapshot.data!['profile'];
          final stickers = snapshot.data!['stickers'] as List;

          // 💡 레이아웃: 페이지당 6개 (2열 3행)
          const int itemsPerPage = 6;
          int totalPages = (stickers.length / itemsPerPage).ceil();
          List<Widget> passportPages = [_buildIdentityPage(profile)];

          for (var i = 0; i < stickers.length; i += itemsPerPage) {
            int end = (i + itemsPerPage > stickers.length)
                ? stickers.length
                : i + itemsPerPage;
            var chunk = stickers.sublist(i, end);
            int currentPage = (i ~/ itemsPerPage) + 1;

            // 💡 페이지 번호 복구 (VISAS 1/2)
            passportPages.add(
              _buildStickerPage("VISAS ($currentPage/$totalPages)", chunk),
            );
          }
          return PageView(controller: _pageController, children: passportPages);
        },
      ),
    );
  }

  // 🎫 신원 정보 페이지
  Widget _buildIdentityPage(dynamic profile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 60, 30, 20),
      child: Column(
        children: [
          const Text(
            "REPUBLIC OF KOREA",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              fontSize: 14,
              color: Colors.brown,
            ),
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Container(
                width: 100,
                height: 125,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.brown.withOpacity(0.1)),
                ),
                child: profile?['profile_image_url'] != null
                    ? Image.network(
                        profile['profile_image_url'],
                        fit: BoxFit.cover,
                      )
                    : const Icon(Icons.person, size: 50, color: Colors.grey),
              ),
              const SizedBox(width: 25),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoField(
                      "SURNAME",
                      profile?['nickname']?.toUpperCase() ?? "TRAVELER",
                    ),
                    _infoField("NATIONALITY", "KOREA"),
                    _infoField("DATE OF ISSUE", "24 JAN 2026"),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          const Text(
            "P<KOR<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // 🎫 비자 스탬프 페이지
  Widget _buildStickerPage(String title, List pageStickers) {
    return Padding(
      //padding: const EdgeInsets.fromLTRB(25, 25, 25, 10),
      padding: const EdgeInsets.fromLTRB(25, 25, 25, 10),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.brown.withOpacity(0.3),
              letterSpacing: 4,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 5, // 행 간격
                //crossAxisSpacing: 10, // 열 간격 (태평양 방지)
                crossAxisSpacing: 28, // 열 간격 (태평양 방지)
                childAspectRatio: 0.75, // 💡 세로 길이를 충분히 확보하여 이미지를 키움
              ),
              itemCount: pageStickers.length,
              itemBuilder: (context, index) =>
                  _buildStampItem(pageStickers[index]),
            ),
          ),
        ],
      ),
    );
  }

  // 🎨 도장 아이템 (빅 사이즈 + 잉크 효과)
  Widget _buildStampItem(Map<String, dynamic> item) {
    final String dateText = _formatPassportDate(item['created_at']);
    final math.Random random = math.Random(item['id'].hashCode);

    // 🎲 랜덤 효과
    final double randomAngle = (random.nextDouble() - 0.5) * 0.35;
    final double randomOpacity = 0.5 + (random.nextDouble() * 0.2); // 0.5 ~ 0.7

    return Column(
      children: [
        // 💡 핵심: Expanded를 사용해 이미지가 가질 수 있는 최대 공간 확보
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 도장 이미지
              Opacity(
                opacity: item['isUnlocked'] ? 0.95 : 0.05,
                child: item['isUnlocked']
                    ? Image.network(item['asset'] ?? "", fit: BoxFit.cover)
                    : Icon(
                        Icons.circle,
                        color: Colors.brown.withOpacity(0.1),
                        size: 100,
                      ),
              ),
              // 날짜 덧칠 (번짐 효과 적용)
              if (item['isUnlocked'] && dateText.isNotEmpty)
                Transform.rotate(
                  angle: randomAngle,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.red.withOpacity(randomOpacity),
                        width: 1.4,
                      ),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.12),
                          blurRadius: 2,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                    child: Text(
                      dateText,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: Colors.red.withOpacity(randomOpacity),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        shadows: [
                          Shadow(
                            color: Colors.red.withOpacity(0.18),
                            blurRadius: 1.2,
                            offset: const Offset(0.5, 0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4), // 💡 이미지와 텍스트 사이 '황금 간격'
        Text(
          item['name'],
          style: TextStyle(
            fontSize: 11,
            color: Colors.brown.withOpacity(0.7),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12), // 아래 칸과의 구분 여백
      ],
    );
  }

  Widget _infoField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 8,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
