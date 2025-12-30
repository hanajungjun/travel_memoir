/// GeoJSON SIDO_CD → map_region_id 매핑
const Map<String, String> sidoCodeToMapRegionId = {
  '11': 'KR_SEOUL',
  '26': 'KR_BUSAN',
  '27': 'KR_DAEGU',
  '28': 'KR_INCHEON',
  '29': 'KR_GWANGJU',
  '30': 'KR_DAEJEON',
  '31': 'KR_ULSAN',
  '36': 'KR_SEJONG',
  '41': 'KR_GG',
  '51': 'KR_GW', // 강원특별자치도
  '43': 'KR_CB',
  '44': 'KR_CN',
  '52': 'KR_JB',
  '46': 'KR_JN',
  '47': 'KR_GB',
  '48': 'KR_GN',
  '50': 'KR_JEJU',
};

/// map_region_id → GeoJSON SIDO_CD (역방향, 지도용)
const Map<String, String> mapRegionIdToSidoCode = {
  'KR_SEOUL': '11',
  'KR_BUSAN': '26',
  'KR_DAEGU': '27',
  'KR_INCHEON': '28',
  'KR_GWANGJU': '29',
  'KR_DAEJEON': '30',
  'KR_ULSAN': '31',
  'KR_SEJONG': '36',
  'KR_GG': '41',
  'KR_GW': '51',
  'KR_CB': '43',
  'KR_CN': '44',
  'KR_JB': '52',
  'KR_JN': '46',
  'KR_GB': '47',
  'KR_GN': '48',
  'KR_JEJU': '50',
};
