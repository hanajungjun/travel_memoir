import 'package:shared_preferences/shared_preferences.dart';

class TutorialManager {
  static const String _keyPrefix = 'tutorial_step_';
  static const int _maxStep = 999; // 튜토리얼 완전 종료 값

  static int currentStep = 1;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    currentStep = prefs.getInt('current_tutorial_step') ?? 1;
  }

  static Future<void> markStepComplete(int step) async {
    if (step == currentStep) {
      currentStep++;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('current_tutorial_step', currentStep);
    }
  }

  // ✅ Skip 버튼: 튜토리얼 전체 영구 종료
  static Future<void> skipAll() async {
    currentStep = _maxStep;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_tutorial_step', _maxStep);
  }
}
