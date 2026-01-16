// lib/services/network_service.dart

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class NetworkService {
  // 싱글톤 패턴: 이 클래스의 인스턴스는 앱 전체에서 딱 하나만 존재하게 함
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  // ⭐ 핵심: 현재 연결 상태를 실시간으로 알려주는 알리미 (기본값: true/연결됨)
  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier(true);

  // 초기화 함수: 앱 켤 때 딱 한 번 호출
  Future<void> initialize() async {
    // 1. 앱 켜자마자 현재 상태 확인
    final List<ConnectivityResult> result = await _connectivity
        .checkConnectivity();
    _updateState(result);

    // 2. 사용 중에 상태가 바뀌는지 계속 감시 (리스너 등록)
    _subscription = _connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> result,
    ) {
      _updateState(result);
    });
  }

  // 상태 업데이트 로직 (연결 상태를 판단해서 알리미에 값 전달)
  void _updateState(List<ConnectivityResult> result) {
    // 연결 정보가 'none'(없음)이 아니면 연결된 것으로 간주
    bool hasConnection =
        result.isNotEmpty && !result.contains(ConnectivityResult.none);

    // 알리미에게 최신 상태 업데이트!
    isConnectedNotifier.value = hasConnection;

    debugPrint(
      '🌐 네트워크 상태 변경: ${hasConnection ? "연결됨 ✅" : "연결 끊김 ❌"} ($result)',
    );
  }

  // 앱 종료 시 리소스 정리
  void dispose() {
    _subscription?.cancel();
    isConnectedNotifier.dispose();
  }
}
