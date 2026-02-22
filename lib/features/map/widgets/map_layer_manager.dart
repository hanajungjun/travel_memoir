// map_layer_manager.dart
// Mapbox Style 레이어·소스의 CRUD와 순서 조정만 담당.
// 비즈니스 로직(색상 결정 등)은 포함하지 않음.

import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:travel_memoir/features/map/widgets/map_constants.dart';
import 'package:travel_memoir/features/map/widgets/detailed_map_config.dart';
import 'package:travel_memoir/features/map/widgets/map_expression_builder.dart';
import 'package:travel_memoir/features/map/widgets/travel_map_data.dart';

class MapLayerManager {
  final StyleManager style;

  MapLayerManager(this.style);

  // ── 레이어·소스 제거 ─────────────────────────────────────────────────────

  Future<void> removeLayerAndSource(String layerId, String sourceId) async {
    await _tryRemoveLayer(layerId);
    await _tryRemoveSource(sourceId);
  }

  Future<void> _tryRemoveLayer(String id) async {
    try {
      if (await style.styleLayerExists(id)) {
        await style.removeStyleLayer(id);
      }
    } catch (_) {}
  }

  Future<void> _tryRemoveSource(String id) async {
    try {
      if (await style.styleSourceExists(id)) {
        await style.removeStyleSource(id);
      }
    } catch (_) {}
  }

  // ── 월드맵 ──────────────────────────────────────────────────────────────

  /// 월드 GeoJSON 로드 → Source·Layer 추가 → 레이어 순서 조정
  Future<void> setupWorldLayer(String worldJson) async {
    await removeLayerAndSource(
      MapConstants.worldFillLayer,
      MapConstants.worldSource,
    );

    await style.addSource(
      GeoJsonSource(id: MapConstants.worldSource, data: worldJson),
    );
    await style.addLayer(
      FillLayer(
        id: MapConstants.worldFillLayer,
        sourceId: MapConstants.worldSource,
      ),
    );
    await _reorderWorldLayers();
  }

  Future<void> _reorderWorldLayers() async {
    final layers = await style.getStyleLayers();

    String? topmostRoadId;
    String? hillshadeId;

    for (final l in layers) {
      if (l == null) continue;
      if (l.id.contains('road') || l.id.contains('admin')) {
        topmostRoadId = l.id;
      }
      if (l.id.contains('hillshade') || l.id.contains('terrain')) {
        hillshadeId = l.id;
      }
    }

    if (topmostRoadId != null) {
      await style.moveStyleLayer(
        MapConstants.worldFillLayer,
        LayerPosition(above: topmostRoadId),
      );
    }
    if (hillshadeId != null) {
      await style.moveStyleLayer(
        hillshadeId,
        LayerPosition(above: MapConstants.worldFillLayer),
      );
    }
    if (await style.styleLayerExists('country-label')) {
      await style.moveStyleLayer(
        'country-label',
        LayerPosition(above: hillshadeId ?? MapConstants.worldFillLayer),
      );
    }
  }

  // ── 월드맵 Expression 적용 ──────────────────────────────────────────────

  Future<void> applyWorldExpressions({
    required TravelMapData data,
    required bool hasUsAccess,
    required List<String> purchasedSubMapCodes, // US 제외
    required String doneHex,
    required String activeHex,
    required String subMapBaseHex,
    required String usHex,
  }) async {
    await style.setStyleLayerProperty(
      MapConstants.worldFillLayer,
      'filter',
      MapExpressionBuilder.worldFilter(data.visitedCountries),
    );
    await style.setStyleLayerProperty(
      MapConstants.worldFillLayer,
      'fill-color',
      MapExpressionBuilder.worldFillColor(
        completedCountries: data.completedCountries,
        subMapCountryCodes: purchasedSubMapCodes,
        hasUsAccess: hasUsAccess,
        doneHex: doneHex,
        activeHex: activeHex,
        subMapBaseHex: subMapBaseHex,
        usHex: usHex,
      ),
    );
    await style.setStyleLayerProperty(
      MapConstants.worldFillLayer,
      'fill-opacity',
      MapExpressionBuilder.worldFillOpacity(hasUsAccess: hasUsAccess),
    );
  }

  // ── 서브맵(상세 지도) ────────────────────────────────────────────────────

  Future<void> setupSubMapLayer(DetailedMapConfig config) async {
    await removeLayerAndSource(config.layerId, config.sourceId);

    final json = await rootBundle.loadString(config.geoJsonPath);
    await style.addSource(GeoJsonSource(id: config.sourceId, data: json));
    await style.addLayer(
      FillLayer(id: config.layerId, sourceId: config.sourceId),
    );
  }

  Future<void> applySubMapExpressions({
    required DetailedMapConfig config,
    required Set<String> visitedRegions,
    required Set<String> completedRegions,
    required String doneHex,
    required String activeHex,
  }) async {
    final isUs = config.countryCode == MapConstants.usCode;

    await style.setStyleLayerProperty(
      config.layerId,
      'filter',
      MapExpressionBuilder.subMapFilter(visitedRegions),
    );
    await style.setStyleLayerProperty(
      config.layerId,
      'fill-color',
      MapExpressionBuilder.subMapFillColor(
        completedRegions: completedRegions,
        doneHex: doneHex,
        activeHex: activeHex,
      ),
    );
    await style.setStyleLayerProperty(
      config.layerId,
      'fill-opacity',
      MapExpressionBuilder.subMapFillOpacity(
        isUs: isUs,
        completedRegions: completedRegions,
      ),
    );
  }

  // ── 라벨 현지화 ──────────────────────────────────────────────────────────

  Future<void> localizeLabels(String languageCode) async {
    try {
      final layers = await style.getStyleLayers();
      for (final l in layers) {
        if (l == null) continue;
        if (l.id.contains('label') || l.id.contains('place')) {
          await style.setStyleLayerProperty(l.id, 'text-field', [
            'get',
            'name_$languageCode',
          ]);
          await style.setStyleLayerProperty(l.id, 'text-opacity', 0.4);
        }
      }
    } catch (e) {
      // 현지화 실패는 치명적이지 않으므로 로그만 기록
      assert(() {
        // ignore: avoid_print
        print('⚠️ [MapLayerManager] localizeLabels 실패: $e');
        return true;
      }());
    }
  }
}
