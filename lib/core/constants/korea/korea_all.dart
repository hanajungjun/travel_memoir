import 'korea_region.dart';

import 'gyeongbuk.dart';
import 'gyeonggi.dart';
//import 'seoul.dart';
import 'gyeongnam.dart';
import 'chungbuk.dart';
import 'chungnam.dart';
import 'jeonbuk.dart';
import 'jeonnam.dart';
import 'gangwon.dart';
import 'jeju.dart';
import 'metropolitan.dart';

const List<KoreaRegion> koreaRegions = [
  ...gyeongbukRegions,
  ...gyeonggiRegions,
  //...seoulRegions,
  ...chungbukRegions,
  ...chungnamRegions,
  ...gyeongnamRegions,
  ...jeonbukRegions,
  ...jeonnamRegions,
  ...gangwonRegions,
  ...jejuRegions,
  ...metropolitanRegions,
];
