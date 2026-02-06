import 'package:flutter/material.dart';

// 🎯 PageRoute 대신 ModalRoute<void>를 사용해야 에러가 안 납니다!
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();
