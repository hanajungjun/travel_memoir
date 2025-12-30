import 'korea_region.dart';

import 'metropolitan.dart'; // ✅ 추가
import 'seoul.dart';

import 'gyeonggi.dart';
import 'chungbuk.dart';
import 'chungnam.dart';
import 'gyeongbuk.dart';
import 'gyeongnam.dart';
import 'jeonbuk.dart';
import 'jeonnam.dart';
import 'gangwon.dart';
import 'jeju.dart';

/// 대한민국 전체 지역 리스트 (현재 사용 기준)
const List<KoreaRegion> koreaRegions = [
  // ===== 광역시 / 특별시 (현재 기준) =====
  ...metropolitanRegions,

  // ===== 경기 =====
  ...gyeonggiRegions,

  // ===== 충청 =====
  ...chungbukRegions,
  ...chungnamRegions,

  // ===== 경상 =====
  ...gyeongbukRegions,
  ...gyeongnamRegions,

  // ===== 전라 =====
  ...jeonbukRegions,
  ...jeonnamRegions,

  // ===== 강원 / 제주 =====
  ...gangwonRegions,
  ...jejuRegions,
];
