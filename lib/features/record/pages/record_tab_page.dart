import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:travel_memoir/app/route_observer.dart';
import 'package:travel_memoir/services/travel_list_service.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

// ✨ 방금 만든 카드 파일 임포트 (파일명/경로 확인!)
import 'record_cards.dart';

class RecordTabPage extends StatefulWidget {
  const RecordTabPage({super.key});

  @override
  State<RecordTabPage> createState() => _RecordTabPageState();
}

class _RecordTabPageState extends State<RecordTabPage> with RouteAware {
  final PageController _controller = PageController();
  late Future<List<Map<String, dynamic>>> _future;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = _getCompletedTravels();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _pollingTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final travels = snapshot.data!;
          if (travels.isEmpty) {
            return Center(
              child: Text(
                'no_completed_travels'.tr(),
                style: AppTextStyles.bodyMuted,
              ),
            );
          }

          return PageView.builder(
            controller: _controller,
            scrollDirection: Axis.vertical,
            itemCount: travels.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                // 분리된 public 클래스 사용
                return SummaryHeroCard(
                  totalCount: travels.length,
                  lastTravel: travels.first,
                );
              }

              final travel = travels[index - 1];
              // 분리된 public 클래스 사용
              return TravelRecordCard(travel: travel, onReturn: _reload);
            },
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getCompletedTravels() async {
    final travels = await TravelListService.getTravels();
    final completed = travels.where((t) => t['is_completed'] == true).toList();
    completed.sort((a, b) => b['end_date'].compareTo(a['end_date']));

    final stillProcessing = completed.any(
      (t) =>
          (t['cover_image_url'] == null) ||
          (t['ai_cover_summary'] ?? '').toString().isEmpty,
    );

    if (stillProcessing) {
      if (_pollingTimer == null || !_pollingTimer!.isActive) {
        _pollingTimer = Timer.periodic(
          const Duration(seconds: 3),
          (_) => _reload(),
        );
      }
    } else {
      _pollingTimer?.cancel();
      _pollingTimer = null;
      HapticFeedback.lightImpact();
    }
    return completed;
  }
}
