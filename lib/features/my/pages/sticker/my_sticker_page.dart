import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class MyStickerPage extends StatefulWidget {
  const MyStickerPage({super.key});

  @override
  State<MyStickerPage> createState() => _MyStickerPageState();
}

class _MyStickerPageState extends State<MyStickerPage> {
  final PageController _pageController = PageController();
  final SupabaseClient _supabase = Supabase.instance.client;
  late Future<Map<String, dynamic>> _dataFuture;

  // 페이지 플립 애니메이션 변수
  double _currentPage = 0.0;
  final String _backgroundImage = 'assets/images/passport_watermark.png';

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();

    _pageController.addListener(() {
      if (mounted) {
        setState(() {
          _currentPage = _pageController.page ?? 0.0;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 날짜 포맷팅
  String _formatPassportDate(String? dateStr) {
    if (dateStr == null) return "DATE UNKNOWN";
    try {
      DateTime dt = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy', 'en_US').format(dt).toUpperCase();
    } catch (e) {
      return "DATE UNKNOWN";
    }
  }

  // 여권 하단 MRZ 텍스트 생성
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

  // MyStickerPage.dart 내의 _loadData 함수 수정

  Future<Map<String, dynamic>> _loadData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {};

    // 1️⃣ 유저 프로필 가져오기
    final profile = await _supabase
        .from('users')
        .select()
        .eq('auth_uid', user.id)
        .maybeSingle();

    // 2️⃣ 방문한 국가 리스트 가져오기 (visited_countries)
    final List<dynamic> visitedRows = await _supabase
        .from('visited_countries')
        .select()
        .eq('user_id', user.id)
        .order('first_visited_at', ascending: false);

    // 3️⃣ 국가 마스터 정보 가져오기 (passport_countries)
    // 모든 국가의 한글/영문 이름을 한꺼번에 가져와서 캐시처럼 씁니다.
    final List<dynamic> countryMaster = await _supabase
        .from('passport_countries')
        .select('code, name_ko, name_en');

    // 조회를 위해 Map으로 변환 { 'KR': {name_ko: '대한민국', ...} }
    final Map<String, dynamic> countryMap = {
      for (var item in countryMaster) item['code']: item,
    };

    debugPrint(
      "🚨 [MY_STICKER_PAGE] 방문 국가: ${visitedRows.length}개 / 마스터 로드: ${countryMaster.length}개",
    );

    final List stickers = visitedRows.map((row) {
      final bool isEn = context.locale.languageCode == 'en';
      final String code = row['country_code'];

      // 🎯 마스터 테이블에서 이름 찾기, 없으면 visited_countries의 기본값 사용
      final master = countryMap[code];
      final String displayName = isEn
          ? (master?['name_en'] ?? row['country_name'] ?? 'GLOBAL')
          : (master?['name_ko'] ?? row['country_name'] ?? '여행지');

      return {
        'id': row['id'],
        'code': code,
        'name': displayName.toUpperCase(), // 영문은 대문자로 깔끔하게
        'isUnlocked': true,
        'created_at': row['first_visited_at'],
        'asset': _supabase.storage.from('stickers').getPublicUrl('$code.webp'),
      };
    }).toList();

    return {'profile': profile, 'stickers': stickers};
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
          int totalPages = (stickers.length / itemsPerPage).ceil();
          if (totalPages == 0) totalPages = 1;

          List<Widget> passportPages = [_buildIdentityPage(profile)];

          // DB 데이터 개수만큼만 비자 페이지 생성
          for (var i = 0; i < stickers.length; i += itemsPerPage) {
            int end = (i + itemsPerPage > stickers.length)
                ? stickers.length
                : i + itemsPerPage;
            var chunk = stickers.sublist(i, end);
            int currentPage = (i ~/ itemsPerPage) + 1;
            passportPages.add(
              _buildStickerPage("VISAS ($currentPage/$totalPages)", chunk),
            );
          }

          // 만약 나라가 하나도 없으면 빈 비자 페이지 추가
          if (stickers.isEmpty) {
            passportPages.add(_buildStickerPage("VISAS (1/1)", []));
          }

          return PageView.builder(
            controller: _pageController,
            itemCount: passportPages.length,
            itemBuilder: (context, index) {
              double delta = index - _currentPage;
              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(delta * 0.6),
                alignment: delta > 0
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: passportPages[index],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBackground() {
    return Positioned.fill(
      child: Opacity(
        opacity: 0.06,
        child: Image.asset(_backgroundImage, fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildProfileImage(dynamic profile) {
    bool isVip = profile?['is_vip'] ?? false;

    return Stack(
      alignment: Alignment.center,
      children: [
        // 1️⃣ 외부 프레임 (VIP는 골드, 일반은 빈티지)
        Container(
          width: 110,
          height: 135,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isVip
                  ? const Color(0xFFD4AF37)
                  : Colors.brown.withOpacity(0.2),
              width: isVip ? 3 : 1,
            ),
            boxShadow: isVip
                ? [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          padding: const EdgeInsets.all(4), // 프레임 두께만큼 안쪽 여백
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: profile?['profile_image_url'] != null
                ? Image.network(profile['profile_image_url'], fit: BoxFit.cover)
                : const Icon(Icons.person, size: 50, color: Colors.grey),
          ),
        ),

        // 2️⃣ VIP 전용 뱃지 (우측 상단에 살짝 걸치게)
        if (isVip)
          Positioned(
            top: -5,
            right: -5,
            child: Transform.rotate(
              angle: 0.2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFFD4AF37),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: const Icon(Icons.stars, color: Colors.white, size: 18),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildIdentityPage(dynamic profile) {
    // 🛠️ 파서 에러 방지를 위해 명확하게 괄호를 사용한 로직
    bool isVip = profile?['is_vip'] ?? false;

    // 괄호를 추가하여 삼항 연산자와 Null-aware 연산자를 분리했습니다.
    final String? rawSince = isVip
        ? (profile?['vip_since']?.toString())
        : (profile?['premium_since']?.toString());

    final String? rawUntil = isVip
        ? (profile?['vip_until']?.toString())
        : (profile?['premium_until']?.toString());

    String issueDate = _formatPassportDate(rawSince);
    String expiryDate = _formatPassportDate(rawUntil);

    String displayNationality =
        profile?['nationality']?.toString().toUpperCase() ?? "MARS";

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
                      _buildProfileImage(profile),
                      const SizedBox(height: 12),
                      _bearerSignature(profile?['nickname'] ?? "TRAVELER"),
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
                child: pageStickers.isEmpty
                    ? Center(
                        child: Text(
                          "NO STAMPS YET",
                          style: TextStyle(
                            color: Colors.brown.withOpacity(0.1),
                            letterSpacing: 2,
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: EdgeInsets.zero,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
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
    final math.Random random = math.Random(item['id'].toString().hashCode);
    final double randomAngle = (random.nextDouble() - 0.5) * 0.35;
    final double randomOpacity = 0.5 + (random.nextDouble() * 0.2);

    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: 0.95,
                child: Image.network(
                  item['asset'] ?? "",
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.flag,
                    color: Colors.brown.withOpacity(0.1),
                    size: 100,
                  ),
                ),
              ),
              if (dateText.isNotEmpty)
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

  Widget _infoField(
    String label,
    String value, {
    bool useSignatureFont = false,
  }) {
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
            style: useSignatureFont
                ? GoogleFonts.nanumBrushScript(
                    fontSize: 24,
                    color: const Color(0xFF1A237E),
                  )
                : const TextStyle(
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
