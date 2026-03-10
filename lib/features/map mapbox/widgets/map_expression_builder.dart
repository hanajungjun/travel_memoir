// map_expression_builder.dart
// Mapbox GL Expression을 순수 함수로 생성.
// UI·비동기 의존성 없음 → 단독 테스트 가능.

import 'package:travel_memoir/features/map/widgets/map_constants.dart';

class MapExpressionBuilder {
  MapExpressionBuilder._();

  // ── ISO 코드 매칭 헬퍼 ───────────────────────────────────────────────────

  /// 세 가지 ISO 필드 중 하나라도 일치하면 true인 expression
  static List<dynamic> _isoMatchAny(String code) => [
    'any',
    [
      '==',
      ['get', 'ISO_A2'],
      code,
    ],
    [
      '==',
      ['get', 'iso_a2'],
      code,
    ],
    [
      '==',
      ['get', 'ISO_A2_EH'],
      code,
    ],
  ];

  /// 세 가지 ISO 필드 중 하나라도 목록에 포함되면 true인 expression
  static List<dynamic> _isoInAny(List<String> codes) => [
    'any',
    [
      'in',
      ['get', 'ISO_A2_EH'],
      ['literal', codes],
    ],
    [
      'in',
      ['get', 'iso_a2'],
      ['literal', codes],
    ],
    [
      'in',
      ['get', 'ISO_A2'],
      ['literal', codes],
    ],
  ];

  // ── 월드맵 expressions ──────────────────────────────────────────────────

  /// 방문한 국가만 표시하는 filter expression
  static List<dynamic> worldFilter(Set<String> visitedCountries) {
    final codes = visitedCountries.toList();
    return _isoInAny(codes);
  }

  /// fill-color expression
  /// - US 구매 → usHex + 반투명(worldOpacity 에서 처리)
  /// - 기타 서브맵 보유 → subMapBaseHex
  /// - 완료 국가 → doneHex
  /// - 미완료 방문 국가 → activeHex
  static List<dynamic> worldFillColor({
    required Set<String> completedCountries,
    required List<String> subMapCountryCodes, // 구매된 서브맵(US 제외)
    required bool hasUsAccess,
    required String doneHex,
    required String activeHex,
    required String subMapBaseHex,
    required String usHex,
  }) {
    final expr = <dynamic>['case'];

    // 1) US 구매 → usHex
    if (hasUsAccess) {
      expr
        ..add(_isoMatchAny(MapConstants.usCode))
        ..add(usHex);
    }

    // 2) 기타 서브맵 보유 국가 → subMapBaseHex
    for (final code in subMapCountryCodes) {
      expr
        ..add(_isoMatchAny(code))
        ..add(subMapBaseHex);
    }

    // 3) 완료 국가 → doneHex
    expr
      ..add(_isoInAny(completedCountries.toList()))
      ..add(doneHex);

    // 4) 기본(방문했지만 미완료) → activeHex
    expr.add(activeHex);

    return expr;
  }

  /// fill-opacity expression
  /// US 구매 시 미국은 반투명, 나머지는 defaultOpacity
  static dynamic worldFillOpacity({required bool hasUsAccess}) {
    if (!hasUsAccess) return MapConstants.defaultOpacity;

    return [
      'case',
      _isoMatchAny(MapConstants.usCode),
      MapConstants.usBaseOpacity,
      MapConstants.defaultOpacity,
    ];
  }

  // ── 서브맵 expressions ──────────────────────────────────────────────────

  /// 방문한 지역만 표시하는 filter expression
  static List<dynamic> subMapFilter(Set<String> visitedRegions) => [
    'in',
    [
      'upcase',
      ['get', 'NAME'],
    ],
    ['literal', visitedRegions.toList()],
  ];

  /// fill-color expression
  static List<dynamic> subMapFillColor({
    required Set<String> completedRegions,
    required String doneHex,
    required String activeHex,
  }) => [
    'case',
    [
      'in',
      [
        'upcase',
        ['get', 'NAME'],
      ],
      ['literal', completedRegions.toList()],
    ],
    doneHex,
    activeHex,
  ];

  /// fill-opacity expression (US는 방문/미완료 구분, 나머지 단일값)
  static dynamic subMapFillOpacity({
    required bool isUs,
    required Set<String> completedRegions,
  }) {
    if (!isUs) return MapConstants.defaultOpacity;

    return [
      'case',
      [
        'in',
        [
          'upcase',
          ['get', 'NAME'],
        ],
        ['literal', completedRegions.toList()],
      ],
      MapConstants.usVisitedOpacity,
      MapConstants.usActiveOpacity,
    ];
  }
}
