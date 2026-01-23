import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyStickerPage extends StatefulWidget {
  const MyStickerPage({super.key});

  @override
  State<MyStickerPage> createState() => _MyStickerPageState();
}

class _MyStickerPageState extends State<MyStickerPage>
    with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;

  late Future<List<Map<String, dynamic>>> _stickersFuture;

  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _stickersFuture = _loadStickers();

    // 🔥 새 스티커 획득 연출용
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getStickerUrl(String countryCode) {
    return _supabase.storage.from('stickers').getPublicUrl('$countryCode.png');
  }

  Future<List<Map<String, dynamic>>> _loadStickers() async {
    final allCountries = [
      {'code': 'FR', 'name': 'France'},
      {'code': 'JP', 'name': 'Japan'},
      {'code': 'US', 'name': 'United States'},
      {'code': 'IT', 'name': 'Italy'},
      {'code': 'ES', 'name': 'Spain'},
      {'code': 'DE', 'name': 'Germany'},
      {'code': 'CA', 'name': 'Canada'},
      {'code': 'GB', 'name': 'United Kingdom'},
    ];

    final rows = await _supabase
        .from('visited_countries')
        .select('country_code, country_name, sticker_image_url');

    final Map<String, Map<String, dynamic>> visitedMap = {
      for (final r in rows)
        r['country_code']: {
          'name': r['country_name'],
          'asset': r['sticker_image_url'],
          'isUnlocked': true,
        },
    };

    return allCountries.map((c) {
      final visited = visitedMap[c['code']];
      return {
        'code': c['code'],
        'name': c['name'],
        'asset': visited?['asset'],
        'isUnlocked': visited != null,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('my_stickers'.tr()),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _stickersFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final stickers = snapshot.data!;

          return GridView.builder(
            padding: const EdgeInsets.all(25),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 25,
              crossAxisSpacing: 20,
              childAspectRatio: 0.9,
            ),
            itemCount: stickers.length,
            itemBuilder: (context, index) {
              return _buildSticker(stickers[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildSticker(Map<String, dynamic> country) {
    final bool isUnlocked = country['isUnlocked'];
    final String countryCode = country['code'];
    final String? imageUrl = country['asset'];

    return ScaleTransition(
      scale: isUnlocked ? _scaleAnimation : const AlwaysStoppedAnimation(1),
      child: Column(
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipPath(
                clipper: HexagonClipper(),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: isUnlocked ? Colors.white : Colors.grey.shade300,
                    ),

                    // ✅ 이미지 로딩 + 실패 대비
                    if (isUnlocked)
                      Image.network(
                        imageUrl ?? _getStickerUrl(countryCode),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.hourglass_top,
                            color: Colors.grey,
                            size: 28,
                          ),
                        ),
                      ),

                    if (!isUnlocked)
                      const Center(
                        child: Icon(
                          Icons.lock,
                          color: Colors.white70,
                          size: 28,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            country['name'],
            style: TextStyle(
              fontSize: 12,
              fontWeight: isUnlocked ? FontWeight.bold : FontWeight.normal,
              color: isUnlocked ? Colors.black87 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

class HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    path.moveTo(w * 0.5, 0);
    path.lineTo(w, h * 0.25);
    path.lineTo(w, h * 0.75);
    path.lineTo(w * 0.5, h);
    path.lineTo(0, h * 0.75);
    path.lineTo(0, h * 0.25);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
