import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart'; // ⭐ 추가
import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ⭐ intl 로케일 초기화 (한국어)
  await initializeDateFormatting('ko_KR', null);

  runApp(const TravelMemoirApp());
}
