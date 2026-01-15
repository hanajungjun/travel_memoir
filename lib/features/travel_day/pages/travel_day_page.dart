import 'dart:io';
import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lottie/lottie.dart';

import 'package:travel_memoir/services/gemini_service.dart';
import 'package:travel_memoir/services/image_upload_service.dart';
import 'package:travel_memoir/services/travel_day_service.dart';
import 'package:travel_memoir/services/travel_complete_service.dart';
import 'package:travel_memoir/services/prompt_cache.dart';
import 'package:travel_memoir/services/stamp_service.dart';

import 'package:travel_memoir/models/image_style_model.dart';
import 'package:travel_memoir/core/widgets/image_style_picker.dart';
import 'package:travel_memoir/core/widgets/ad_request_dialog.dart';

import 'package:travel_memoir/core/utils/date_utils.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/features/travel_day/pages/travel_completion_page.dart';

class TravelDayPage extends StatefulWidget {
  final String travelId;
  final String placeName;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime date;
  final Map<String, dynamic>? initialDiary;

  const TravelDayPage({
    super.key,
    required this.travelId,
    required this.placeName,
    required this.startDate,
    required this.endDate,
    required this.date,
    this.initialDiary,
  });

  @override
  State<TravelDayPage> createState() => _TravelDayPageState();
}

class _TravelDayPageState extends State<TravelDayPage> {
  final StampService _stampService = StampService();
  final TextEditingController _contentController = TextEditingController();

  ImageStyleModel? _selectedStyle;
  final List<File> _localPhotos = [];
  final List<String> _uploadedPhotoUrls = [];

  Uint8List? _generatedImage;
  String? _imageUrl;
  String? _summaryText;
  String? _diaryId;

  bool _loading = false;
  String _loadingMessage = "";

  int _dailyStamps = 0;
  int _paidStamps = 0;
  bool _usePaidStampMode = false;
  String _travelType = 'domestic';

  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;

  String get _userId => Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _contentController.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    await _loadDiary();
    await _refreshStampCounts();
    _loadAds();
    _checkTripType();
  }

  Future<void> _refreshStampCounts() async {
    final stamps = await _stampService.getStampData(_userId);
    if (!mounted || stamps == null) return;
    setState(() {
      _dailyStamps = stamps['daily_stamps'] ?? 0;
      _paidStamps = stamps['paid_stamps'] ?? 0;
      if (_dailyStamps == 0 && _paidStamps > 0) _usePaidStampMode = true;
    });
  }

  Future<void> _checkTripType() async {
    final tripData = await Supabase.instance.client
        .from('travels')
        .select('travel_type')
        .eq('id', widget.travelId)
        .maybeSingle();
    if (!mounted || tripData == null) return;
    setState(() => _travelType = tripData['travel_type'] ?? 'domestic');
  }

  Future<void> _loadDiary() async {
    if (widget.initialDiary != null) {
      _applyDiaryData(widget.initialDiary!);
      return;
    }
    final diary = await TravelDayService.getDiaryByDate(
      travelId: widget.travelId,
      date: widget.date,
    );
    if (!mounted || diary == null) return;
    _applyDiaryData(diary);
  }

  void _applyDiaryData(Map<String, dynamic> diary) {
    setState(() {
      _diaryId = diary['id']?.toString();
      _contentController.text = diary['text'] ?? '';
      if (diary['photo_urls'] != null) {
        _uploadedPhotoUrls
          ..clear()
          ..addAll(List<String>.from(diary['photo_urls']));
      }
      if (diary['ai_summary'] != null &&
          diary['ai_summary'].toString().isNotEmpty) {
        _imageUrl = TravelDayService.getAiImageUrl(
          travelId: widget.travelId,
          diaryId: _diaryId!,
        );
      }
    });
  }

  void _loadAds() {
    final adId = Platform.isAndroid
        ? 'ca-app-pub-3890698783881393/3553280276'
        : 'ca-app-pub-3890698783881393/4814391052';
    RewardedAd.load(
      adUnitId: adId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => setState(() {
          _rewardedAd = ad;
          _isAdLoaded = true;
        }),
        onAdFailedToLoad: (_) => setState(() => _isAdLoaded = false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _travelType == 'domestic'
        ? AppColors.travelingBlue
        : const Color(0xFF9B59B6);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: TapRegion(
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  elevation: 0,
                  backgroundColor: themeColor,
                  expandedHeight: 80,
                  leading: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  centerTitle: true,
                  title: Text(
                    'Day ${DateUtilsHelper.calculateDayNumber(startDate: widget.startDate, currentDate: widget.date).toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  actions: [_buildAppBarStampToggle()],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(color: themeColor),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 160),
                    child: Column(
                      children: [
                        _buildDiaryCard(themeColor),
                        const SizedBox(height: 20),
                        _buildAiResultCard(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            _buildBottomSaveButton(),
            if (_loading) _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  // ========================= UI =========================

  Widget _buildAppBarStampToggle() {
    return GestureDetector(
      onTap: () => setState(() => _usePaidStampMode = !_usePaidStampMode),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: _usePaidStampMode ? Colors.orange : const Color(0xFF3498DB),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _stampUnit(
              "무료",
              _dailyStamps,
              const Color(0xFF3498DB),
              !_usePaidStampMode,
            ),
            const SizedBox(width: 8),
            _stampUnit(
              "보관",
              _paidStamps,
              const Color(0xFFF39C12),
              _usePaidStampMode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _stampUnit(String label, int count, Color color, bool isActive) {
    return Opacity(
      opacity: isActive ? 1 : 0.4,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(label, style: const TextStyle(fontSize: 10)),
          const SizedBox(width: 4),
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiaryCard(Color themeColor) {
    return Container(
      decoration: _cardDeco(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'diary_hint'.tr(),
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ImageStylePicker(
              onChanged: (style) => setState(() => _selectedStyle = style),
            ),
          ),
          const SizedBox(height: 20),
          _buildGenerateButton(themeColor),
        ],
      ),
    );
  }

  Widget _buildGenerateButton(Color themeColor) {
    return GestureDetector(
      onTap: _loading ? null : _handleGenerateWithStamp,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: themeColor,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(25),
            bottomRight: Radius.circular(25),
          ),
        ),
        child: const Center(
          child: Text(
            'AI 이미지 생성하기',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildAiResultCard() {
    if (_imageUrl == null && _generatedImage == null)
      return const SizedBox.shrink();
    return Container(
      decoration: _cardDeco(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: _imageUrl != null
            ? Image.network(_imageUrl!, fit: BoxFit.cover)
            : Image.memory(_generatedImage!, fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildBottomSaveButton() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        color: const Color(0xFF454B54),
        child: GestureDetector(
          onTap: _loading ? null : _saveDiary,
          child: const Text(
            '기록 저장하기',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset('assets/lottie/ai_magic_wand.json', width: 200),
            const SizedBox(height: 20),
            Text(_loadingMessage, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(25),
    boxShadow: [
      BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20),
    ],
  );

  // ========================= LOGIC =========================

  Future<void> _handleGenerateWithStamp() async {
    FocusScope.of(context).unfocus();
    if (_selectedStyle == null || _contentController.text.trim().isEmpty)
      return;
    setState(() {
      _loading = true;
      _loadingMessage = "AI가 그림을 그리고 있어요...";
    });
    final aiData = await _runAiGeneration();
    setState(() {
      _summaryText = aiData['summary'];
      _generatedImage = aiData['image'];
      _imageUrl = null;
      _loading = false;
    });
  }

  Future<Map<String, dynamic>> _runAiGeneration() async {
    final gemini = GeminiService();
    final summary = await gemini.generateSummary(
      finalPrompt:
          '${PromptCache.textPrompt.content}\n장소:${widget.placeName}\n내용:${_contentController.text}',
      photos: _localPhotos,
    );
    final image = await gemini.generateImage(
      finalPrompt:
          '${PromptCache.imagePrompt.content}\nStyle:\n${_selectedStyle!.prompt}\nSummary:\n$summary',
    );
    return {'summary': summary, 'image': image};
  }

  Future<void> _saveDiary() async {
    FocusScope.of(context).unfocus();
    Navigator.pop(context, true);
  }
}

// ========================= PHOTO THUMB =========================

class _PhotoThumb extends StatelessWidget {
  final Widget image;
  final VoidCallback onDelete;
  const _PhotoThumb({required this.image, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(width: 65, height: 65, child: image),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onDelete,
            child: const CircleAvatar(
              radius: 11,
              backgroundColor: Colors.black54,
              child: Icon(Icons.close, size: 13, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
