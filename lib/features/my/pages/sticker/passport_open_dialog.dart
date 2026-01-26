import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

// --- [1] 여권 애니메이션 다이얼로그 (간지 나는 앞표지 적용) ---
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
              // 속지 페이지
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
                child: const MyStickerPage(),
              ),

              // 3D 회전 앞표지
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

  // ✅ [수정] 이미지 기반의 개간지 앞표지
  Widget _buildCoverFront() {
    return Container(
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage(
            'assets/images/passport_cover_front.png',
          ), // 생성한 이미지 경로
          fit: BoxFit.cover,
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(15),
          bottomRight: Radius.circular(15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(10, 10),
          ),
        ],
      ),
    );
  }
}

// --- [2] 여권 속지 시스템 (최종 디테일 통합 버전) ---
class MyStickerPage extends StatefulWidget {
  const MyStickerPage({super.key});

  @override
  State<MyStickerPage> createState() => _MyStickerPageState();
}

class _MyStickerPageState extends State<MyStickerPage> {
  final PageController _pageController = PageController();
  final SupabaseClient _supabase = Supabase.instance.client;
  late Future<Map<String, dynamic>> _dataFuture;

  final String _backgroundImage = 'assets/images/passport_watermark.png';

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  // 여권 스타일 날짜 변환
  String _formatPassportDate(String? dateStr) {
    if (dateStr == null) return "DATE UNKNOWN";
    try {
      DateTime dt = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy', 'en_US').format(dt).toUpperCase();
    } catch (e) {
      return "DATE UNKNOWN";
    }
  }

  // 동적 MRZ 생성
  String _generateMrzText(dynamic profile) {
    String nationality = (profile?['nationality']?.toString() ?? "KOR")
        .padRight(3, '<')
        .substring(0, 3)
        .toUpperCase();
    String name = (profile?['nickname']?.toString() ?? "TRAVELER")
        .toUpperCase()
        .replaceAll(' ', '<');

    return "P<$nationality$name".padRight(44, '<');
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

  Widget _buildBackground() {
    return Positioned.fill(
      child: Opacity(
        opacity: 0.06,
        child: Image.asset(_backgroundImage, fit: BoxFit.cover),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF4F1E1),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final profile = snapshot.data!['profile'];
          final stickers = snapshot.data!['stickers'] as List;

          const int itemsPerPage = 6;
          List<Widget> passportPages = [_buildIdentityPage(profile)];

          for (var i = 0; i < stickers.length; i += itemsPerPage) {
            int end = (i + itemsPerPage > stickers.length)
                ? stickers.length
                : i + itemsPerPage;
            var chunk = stickers.sublist(i, end);
            int currentPage = (i ~/ itemsPerPage) + 1;
            int totalPages = (stickers.length / itemsPerPage).ceil();
            passportPages.add(
              _buildStickerPage("VISAS ($currentPage/$totalPages)", chunk),
            );
          }
          return PageView(controller: _pageController, children: passportPages);
        },
      ),
    );
  }

  // 🎫 신원 정보 페이지 (데이터 매칭 및 폰트 크기 +2 적용)
  Widget _buildIdentityPage(dynamic profile) {
    String issueDate = _formatPassportDate(profile?['premium_since']);
    String expiryDate = _formatPassportDate(profile?['premium_until']);
    String displayNationality =
        profile?['nationality']?.toString().toUpperCase() ?? "KOREA";

    return Stack(
      children: [
        _buildBackground(),
        Padding(
          padding: const EdgeInsets.fromLTRB(30, 60, 30, 20),
          child: Column(
            children: [
              Text(
                displayNationality,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  fontSize: 16,
                  color: Colors.brown,
                ),
              ),
              const SizedBox(height: 40),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 100,
                        height: 125,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: Colors.brown.withOpacity(0.1),
                          ),
                        ),
                        child: profile?['profile_image_url'] != null
                            ? Image.network(
                                profile['profile_image_url'],
                                fit: BoxFit.cover,
                              )
                            : const Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.grey,
                              ),
                      ),
                      const SizedBox(height: 12),
                      _bearerSignature(
                        profile?['nickname'] ?? "TRAVELER",
                      ), // ✅ 서명란
                    ],
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
                        _infoField("NATIONALITY", displayNationality),
                        _infoField("DATE OF ISSUE", issueDate),
                        _infoField("DATE OF EXPIRY", expiryDate),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                _generateMrzText(profile),
                style: GoogleFonts.courierPrime(
                  fontSize: 13,
                  color: Colors.black38,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }

  // ✅ 소지인 서명란 위젯
  Widget _bearerSignature(String nickname) {
    return Column(
      children: [
        const Text(
          "Signature of bearer",
          style: TextStyle(
            fontSize: 9,
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 4),
        Stack(
          alignment: Alignment.center,
          children: [
            Container(width: 80, height: 0.5, color: Colors.black26),
            Transform.translate(
              offset: const Offset(0, -5),
              child: Transform.rotate(
                angle: -0.05,
                child: Text(
                  nickname,
                  style: GoogleFonts.nanumBrushScript(
                    fontSize: 20,
                    color: const Color(0xFF1A237E).withOpacity(0.8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStickerPage(String title, List pageStickers) {
    return Stack(
      children: [
        _buildBackground(),
        Padding(
          padding: const EdgeInsets.fromLTRB(25, 25, 25, 10),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.brown.withOpacity(0.3),
                  letterSpacing: 4,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 5,
                    crossAxisSpacing: 28,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: pageStickers.length,
                  itemBuilder: (context, index) =>
                      _buildStampItem(pageStickers[index]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStampItem(Map<String, dynamic> item) {
    final String dateText = _formatPassportDate(item['created_at']);
    final math.Random random = math.Random(item['id'].hashCode);
    final double randomAngle = (random.nextDouble() - 0.5) * 0.35;
    final double randomOpacity = 0.5 + (random.nextDouble() * 0.2);

    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
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
                    ),
                    child: Text(
                      dateText,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: Colors.red.withOpacity(randomOpacity),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          item['name'],
          style: TextStyle(
            fontSize: 13,
            color: Colors.brown.withOpacity(0.7),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _infoField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
