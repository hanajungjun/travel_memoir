// -----------------------------------------------------------------------------
// parse_utils.dart
// -----------------------------------------------------------------------------
// ❖ 공통 파싱/변환 유틸 모음
//
//  ✔ toDoubleSafe(value)
//      - dynamic 타입을 안전하게 double 변환
//      - 숫자(num), 문자열(String), null 모두 처리
//      - API 응답이 숫자/문자 섞여서 올 때 유용
//
// 앞으로 다른 변환 함수들(ex. toIntSafe, toBoolSafe)도 이 파일에 추가하면 됨.
// -----------------------------------------------------------------------------

/// [toDoubleSafe]
/// ---------------------------------------------------------------------------
/// dynamic 타입의 값을 안전하게 double로 변환하는 함수.
///
/// ▌지원되는 입력 타입:
///   - `num` : 그대로 toDouble() 변환
///   - `String` : 숫자로 변환 가능한 문자열이면 double로 변환
///   - `null` : null 반환
///
/// ▌예외 변환 없이 모든 잘못된 타입 입력 시 null 반환하므로
///   API 응답이 예측 불가능한 경우에 매우 안전함.
///
/// ▌사용 예:
///   final lat = toDoubleSafe(json["lat"]);
///   final lng = toDoubleSafe(json["longitude"]);
///
/// ---------------------------------------------------------------------------
double? toDoubleSafe(dynamic value) {
  if (value == null) return null;

  if (value is num) {
    return value.toDouble();
  }

  if (value is String) {
    return double.tryParse(value);
  }

  return null;
}
