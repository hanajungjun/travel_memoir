/// 시군구(SGG) 코드 매핑
/// region_id → sido_cd / sgg_cd 변환
class SggCodeMap {
  /// 내부 매핑 테이블
  static const Map<String, ({String type, String? sidoCd, String? sggCd})>
  _map = {
    // =====================
    // 🔹 광역시 (SIDO)
    // =====================
    'KR_SEOUL': (type: 'sido', sidoCd: '11', sggCd: null),
    'KR_BUSAN': (type: 'sido', sidoCd: '26', sggCd: null),
    'KR_DAEGU': (type: 'sido', sidoCd: '27', sggCd: null),
    'KR_INCHEON': (type: 'sido', sidoCd: '28', sggCd: null),
    'KR_GWANGJU': (type: 'sido', sidoCd: '29', sggCd: null),
    'KR_DAEJEON': (type: 'sido', sidoCd: '30', sggCd: null),
    'KR_ULSAN': (type: 'sido', sidoCd: '31', sggCd: null),
    'KR_SEJONG': (type: 'sido', sidoCd: '36', sggCd: null),

    // =====================
    // 🔹 경기도 (GYEONGGI)
    // =====================
    'KR_GG_SUWON': (type: 'city', sidoCd: '41', sggCd: '41110'),
    'KR_GG_SEONGNAM': (type: 'city', sidoCd: '41', sggCd: '41130'),
    'KR_GG_GOYANG': (type: 'city', sidoCd: '41', sggCd: '41280'),
    'KR_GG_YONGIN': (type: 'city', sidoCd: '41', sggCd: '41460'),
    'KR_GG_BUCHEON': (type: 'city', sidoCd: '41', sggCd: '41190'),
    'KR_GG_ANSAN': (type: 'city', sidoCd: '41', sggCd: '41270'),
    'KR_GG_ANYANG': (type: 'city', sidoCd: '41', sggCd: '41170'),
    'KR_GG_HWASEONG': (type: 'city', sidoCd: '41', sggCd: '41590'),
    'KR_GG_PYEONGTAEK': (type: 'city', sidoCd: '41', sggCd: '41220'),
    'KR_GG_UIJEONGBU': (type: 'city', sidoCd: '41', sggCd: '41150'),
    'KR_GG_SIHEUNG': (type: 'city', sidoCd: '41', sggCd: '41390'),
    'KR_GG_GIMPO': (type: 'city', sidoCd: '41', sggCd: '41570'),
    'KR_GG_PAJU': (type: 'city', sidoCd: '41', sggCd: '41480'),
    'KR_GG_GWANGMYEONG': (type: 'city', sidoCd: '41', sggCd: '41210'),
    'KR_GG_GUNPO': (type: 'city', sidoCd: '41', sggCd: '41410'),
    'KR_GG_GWANGJU': (type: 'city', sidoCd: '41', sggCd: '41610'),
    'KR_GG_GURI': (type: 'city', sidoCd: '41', sggCd: '41310'),
    'KR_GG_NAMYANGJU': (type: 'city', sidoCd: '41', sggCd: '41360'),
    'KR_GG_DONGDUCHEON': (type: 'city', sidoCd: '41', sggCd: '41250'),
    'KR_GG_YANGJU': (type: 'city', sidoCd: '41', sggCd: '41630'),
    'KR_GG_POCHEON': (type: 'city', sidoCd: '41', sggCd: '41650'),
    'KR_GG_ICHEON': (type: 'city', sidoCd: '41', sggCd: '41500'),
    'KR_GG_ANSEONG': (type: 'city', sidoCd: '41', sggCd: '41550'),
    'KR_GG_OSAN': (type: 'city', sidoCd: '41', sggCd: '41370'),
    'KR_GG_HANAM': (type: 'city', sidoCd: '41', sggCd: '41450'),
    'KR_GG_UWANG': (type: 'city', sidoCd: '41', sggCd: '41430'),
    'KR_GG_YEOJU': (type: 'city', sidoCd: '41', sggCd: '41670'),
    'KR_GG_YEONCHEON': (type: 'city', sidoCd: '41', sggCd: '41800'),
    'KR_GG_GAPYEONG': (type: 'city', sidoCd: '41', sggCd: '41820'),
    'KR_GG_YANGPYEONG': (type: 'city', sidoCd: '41', sggCd: '41830'),

    // =====================
    // 🔹 강원특별자치도 (GANGWON)
    // =====================
    'KR_GW_CHUNCHEON': (type: 'city', sidoCd: '51', sggCd: '51110'),
    'KR_GW_WONJU': (type: 'city', sidoCd: '51', sggCd: '51130'),
    'KR_GW_GANGNEUNG': (type: 'city', sidoCd: '51', sggCd: '51150'),
    'KR_GW_DONGHAE': (type: 'city', sidoCd: '51', sggCd: '51170'),
    'KR_GW_TAEBAEK': (type: 'city', sidoCd: '51', sggCd: '51190'),
    'KR_GW_SOKCHO': (type: 'city', sidoCd: '51', sggCd: '51210'),
    'KR_GW_SAMCHEOK': (type: 'city', sidoCd: '51', sggCd: '51230'),

    'KR_GW_HONGCHEON': (type: 'city', sidoCd: '51', sggCd: '51720'),
    'KR_GW_HOENGSEONG': (type: 'city', sidoCd: '51', sggCd: '51730'),
    'KR_GW_YEONGWOL': (type: 'city', sidoCd: '51', sggCd: '51750'),
    'KR_GW_PYEONGCHANG': (type: 'city', sidoCd: '51', sggCd: '51760'),
    'KR_GW_JEONGSEON': (type: 'city', sidoCd: '51', sggCd: '51770'),
    'KR_GW_CHEORWON': (type: 'city', sidoCd: '51', sggCd: '51780'),
    'KR_GW_HWACHEON': (type: 'city', sidoCd: '51', sggCd: '51790'),
    'KR_GW_YANGGU': (type: 'city', sidoCd: '51', sggCd: '51800'),
    'KR_GW_INJE': (type: 'city', sidoCd: '51', sggCd: '51810'),
    'KR_GW_GOSEONG': (type: 'city', sidoCd: '51', sggCd: '51820'),
    'KR_GW_YANGYANG': (type: 'city', sidoCd: '51', sggCd: '51830'),

    // =====================
    // 🔹 충청북도 (CHUNGBUK)
    // =====================
    'KR_CB_CHEONGJU': (type: 'city', sidoCd: '43', sggCd: '43110'),
    'KR_CB_CHUNGJU': (type: 'city', sidoCd: '43', sggCd: '43130'),
    'KR_CB_JECHEON': (type: 'city', sidoCd: '43', sggCd: '43150'),

    'KR_CB_BOEUN': (type: 'city', sidoCd: '43', sggCd: '43720'),
    'KR_CB_OKCHEON': (type: 'city', sidoCd: '43', sggCd: '43730'),
    'KR_CB_YEONGDONG': (type: 'city', sidoCd: '43', sggCd: '43740'),
    'KR_CB_JINCHEON': (type: 'city', sidoCd: '43', sggCd: '43750'),
    'KR_CB_GOESAN': (type: 'city', sidoCd: '43', sggCd: '43760'),
    'KR_CB_EUMSEONG': (type: 'city', sidoCd: '43', sggCd: '43770'),
    'KR_CB_DANYANG': (type: 'city', sidoCd: '43', sggCd: '43780'),

    'KR_CB_JEUNGPYEONG': (type: 'city', sidoCd: '43', sggCd: '43745'),

    // =====================
    // 🔹 충청남도 (CHUNGNAM)
    // =====================
    'KR_CN_CHEONAN': (type: 'city', sidoCd: '44', sggCd: '44130'),
    'KR_CN_GONGJU': (type: 'city', sidoCd: '44', sggCd: '44150'),
    'KR_CN_BORYEONG': (type: 'city', sidoCd: '44', sggCd: '44180'),
    'KR_CN_ASAN': (type: 'city', sidoCd: '44', sggCd: '44200'),
    'KR_CN_SEOSAN': (type: 'city', sidoCd: '44', sggCd: '44210'),
    'KR_CN_NONSAN': (type: 'city', sidoCd: '44', sggCd: '44230'),
    'KR_CN_GYERYONG': (type: 'city', sidoCd: '44', sggCd: '44250'),
    'KR_CN_DANGJIN': (type: 'city', sidoCd: '44', sggCd: '44270'),

    'KR_CN_GEUMSAN': (type: 'city', sidoCd: '44', sggCd: '44710'),
    'KR_CN_BUYEO': (type: 'city', sidoCd: '44', sggCd: '44760'),
    'KR_CN_SEOCHEON': (type: 'city', sidoCd: '44', sggCd: '44770'),
    'KR_CN_CHEONGYANG': (type: 'city', sidoCd: '44', sggCd: '44790'),
    'KR_CN_HONGSEONG': (type: 'city', sidoCd: '44', sggCd: '44800'),
    'KR_CN_YESAN': (type: 'city', sidoCd: '44', sggCd: '44810'),
    'KR_CN_TAEAN': (type: 'city', sidoCd: '44', sggCd: '44825'),

    // =====================
    // 🔹 전라북도 (JEONBUK)
    // =====================
    'KR_JB_JEONJU': (type: 'city', sidoCd: '45', sggCd: '45110'),
    'KR_JB_GUNSAN': (type: 'city', sidoCd: '45', sggCd: '45130'),
    'KR_JB_IKSAN': (type: 'city', sidoCd: '45', sggCd: '45140'),
    'KR_JB_JEONGEUP': (type: 'city', sidoCd: '45', sggCd: '45180'),
    'KR_JB_NAMWON': (type: 'city', sidoCd: '45', sggCd: '45190'),
    'KR_JB_GIMJE': (type: 'city', sidoCd: '45', sggCd: '45210'),

    'KR_JB_WANJU': (type: 'city', sidoCd: '45', sggCd: '45710'),
    'KR_JB_JINAN': (type: 'city', sidoCd: '45', sggCd: '45720'),
    'KR_JB_MUJU': (type: 'city', sidoCd: '45', sggCd: '45730'),
    'KR_JB_JANGSU': (type: 'city', sidoCd: '45', sggCd: '45740'),
    'KR_JB_IMSIL': (type: 'city', sidoCd: '45', sggCd: '45750'),
    'KR_JB_SUNCHANG': (type: 'city', sidoCd: '45', sggCd: '45770'),
    'KR_JB_GOCHANG': (type: 'city', sidoCd: '45', sggCd: '45790'),
    'KR_JB_BUAN': (type: 'city', sidoCd: '45', sggCd: '45800'),

    // =====================
    // 🔹 전라남도 (JEONNAM)
    // =====================
    'KR_JN_MOKPO': (type: 'city', sidoCd: '46', sggCd: '46110'),
    'KR_JN_YEOSU': (type: 'city', sidoCd: '46', sggCd: '46130'),
    'KR_JN_SUNCHEON': (type: 'city', sidoCd: '46', sggCd: '46150'),
    'KR_JN_NAJU': (type: 'city', sidoCd: '46', sggCd: '46170'),
    'KR_JN_GWANGYANG': (type: 'city', sidoCd: '46', sggCd: '46230'),

    'KR_JN_DAMYANG': (type: 'city', sidoCd: '46', sggCd: '46710'),
    'KR_JN_GOKSEONG': (type: 'city', sidoCd: '46', sggCd: '46720'),
    'KR_JN_GURYE': (type: 'city', sidoCd: '46', sggCd: '46730'),
    'KR_JN_GOHEUNG': (type: 'city', sidoCd: '46', sggCd: '46770'),
    'KR_JN_BOSEONG': (type: 'city', sidoCd: '46', sggCd: '46780'),
    'KR_JN_HWASUN': (type: 'city', sidoCd: '46', sggCd: '46790'),
    'KR_JN_JANGHEUNG': (type: 'city', sidoCd: '46', sggCd: '46800'),
    'KR_JN_GANGJIN': (type: 'city', sidoCd: '46', sggCd: '46810'),
    'KR_JN_HAENAM': (type: 'city', sidoCd: '46', sggCd: '46820'),
    'KR_JN_YEONGAM': (type: 'city', sidoCd: '46', sggCd: '46830'),
    'KR_JN_MUAN': (type: 'city', sidoCd: '46', sggCd: '46840'),
    'KR_JN_HAMPYEONG': (type: 'city', sidoCd: '46', sggCd: '46860'),
    'KR_JN_YEONGGWANG': (type: 'city', sidoCd: '46', sggCd: '46870'),
    'KR_JN_JANGSEONG': (type: 'city', sidoCd: '46', sggCd: '46880'),
    'KR_JN_WANDO': (type: 'city', sidoCd: '46', sggCd: '46890'),
    'KR_JN_JINDO': (type: 'city', sidoCd: '46', sggCd: '46900'),
    'KR_JN_SINAN': (type: 'city', sidoCd: '46', sggCd: '46910'),

    // =====================
    // 🔹 경상북도 (GYEONGBUK)
    // =====================
    'KR_GB_POHANG': (type: 'city', sidoCd: '47', sggCd: '47110'),
    'KR_GB_GYEONGJU': (type: 'city', sidoCd: '47', sggCd: '47130'),
    'KR_GB_GIMCHEON': (type: 'city', sidoCd: '47', sggCd: '47150'),
    'KR_GB_ANDONG': (type: 'city', sidoCd: '47', sggCd: '47170'),
    'KR_GB_GUMI': (type: 'city', sidoCd: '47', sggCd: '47190'),
    'KR_GB_YEONGJU': (type: 'city', sidoCd: '47', sggCd: '47210'),
    'KR_GB_YEONGCHEON': (type: 'city', sidoCd: '47', sggCd: '47230'),
    'KR_GB_SANGJU': (type: 'city', sidoCd: '47', sggCd: '47250'),
    'KR_GB_MUNGYEONG': (type: 'city', sidoCd: '47', sggCd: '47280'),
    'KR_GB_GYEONGSAN': (type: 'city', sidoCd: '47', sggCd: '47290'),

    'KR_GB_GUNWI': (type: 'city', sidoCd: '47', sggCd: '47720'),
    'KR_GB_UISEONG': (type: 'city', sidoCd: '47', sggCd: '47730'),
    'KR_GB_CHEONGSONG': (type: 'city', sidoCd: '47', sggCd: '47750'),
    'KR_GB_YEONGYANG': (type: 'city', sidoCd: '47', sggCd: '47760'),
    'KR_GB_YEONGDEOK': (type: 'city', sidoCd: '47', sggCd: '47770'),
    'KR_GB_CHEONGDO': (type: 'city', sidoCd: '47', sggCd: '47820'),
    'KR_GB_GORYEONG': (type: 'city', sidoCd: '47', sggCd: '47830'),
    'KR_GB_SEONGJU': (type: 'city', sidoCd: '47', sggCd: '47840'),
    'KR_GB_CHILGOK': (type: 'city', sidoCd: '47', sggCd: '47850'),
    'KR_GB_YECHEON': (type: 'city', sidoCd: '47', sggCd: '47900'),
    'KR_GB_BONGHWA': (type: 'city', sidoCd: '47', sggCd: '47920'),
    'KR_GB_ULJIN': (type: 'city', sidoCd: '47', sggCd: '47930'),
    'KR_GB_ULLEUNG': (type: 'city', sidoCd: '47', sggCd: '47940'),

    // =====================
    // 🔹 경상남도 (GYEONGNAM)
    // =====================
    'KR_GN_CHANGWON': (type: 'city', sidoCd: '48', sggCd: '48120'),
    'KR_GN_JINJU': (type: 'city', sidoCd: '48', sggCd: '48170'),
    'KR_GN_TONGYEONG': (type: 'city', sidoCd: '48', sggCd: '48220'),
    'KR_GN_SACHEON': (type: 'city', sidoCd: '48', sggCd: '48240'),
    'KR_GN_GIMHAE': (type: 'city', sidoCd: '48', sggCd: '48250'),
    'KR_GN_MIRYANG': (type: 'city', sidoCd: '48', sggCd: '48270'),
    'KR_GN_GEOJE': (type: 'city', sidoCd: '48', sggCd: '48310'),
    'KR_GN_YANGSAN': (type: 'city', sidoCd: '48', sggCd: '48330'),

    'KR_GN_UIRYEONG': (type: 'city', sidoCd: '48', sggCd: '48720'),
    'KR_GN_HAMAN': (type: 'city', sidoCd: '48', sggCd: '48730'),
    'KR_GN_CHANGNYEONG': (type: 'city', sidoCd: '48', sggCd: '48740'),
    'KR_GN_GOSEONG': (type: 'city', sidoCd: '48', sggCd: '48820'),
    'KR_GN_NAMHAE': (type: 'city', sidoCd: '48', sggCd: '48840'),
    'KR_GN_HADONG': (type: 'city', sidoCd: '48', sggCd: '48850'),
    'KR_GN_SANCHEONG': (type: 'city', sidoCd: '48', sggCd: '48860'),
    'KR_GN_HAMYANG': (type: 'city', sidoCd: '48', sggCd: '48870'),
    'KR_GN_GEOCHANG': (type: 'city', sidoCd: '48', sggCd: '48880'),
    'KR_GN_HAPCHEON': (type: 'city', sidoCd: '48', sggCd: '48890'),

    // =====================
    // 🔹 제주특별자치도 (JEJU)
    // =====================
    'KR_JJ_JEJU': (type: 'city', sidoCd: '50', sggCd: '50110'),
    'KR_JJ_SEOGWIPO': (type: 'city', sidoCd: '50', sggCd: '50130'),
  };

  /// regionId 기준으로 코드 반환
  /// city 인 경우만 sgg_cd 존재
  static ({String? sidoCd, String? sggCd, String type}) fromRegionId(
    String regionId,
  ) {
    return _map[regionId] ?? (type: 'city', sidoCd: null, sggCd: null);
  }

  /// sgg_cd를 기반으로 regionId(Key)를 찾는 역조회 함수
  static String getRegionIdFromSggCd(String sggCd) {
    try {
      // _map을 순회하면서 sggCd가 일치하는 첫 번째 key를 반환합니다.
      return _map.entries.firstWhere((entry) => entry.value.sggCd == sggCd).key;
    } catch (e) {
      return ''; // 못 찾으면 빈 문자열
    }
  }
}
