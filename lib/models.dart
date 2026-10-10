import 'package:flutter/material.dart';

class Shop {
  final String id;
  final String name;
  final String icon;
  final String discount;
  final String shortDiscount;
  final String description;
  final String location;
  final String category;
  final int priority;
  final String mallId;
  final String imageUrl;
  final String infoImageUrl;
  final double? mapX;
  final double? mapY;
  final double? mapWidth;
  final double? mapHeight;
  final List<double>? imageTransform;
  final List<double>? infoImageTransform;
  final List<List<double>>? rawMapPolygon;   // [[x,y],[x,y],...] из jsonb
  final double? entryX;
  final double? entryY;
  final double? labelX;
  final double? labelY;
  final double? rawLabelAngle;
  final List<double>? rawLabelRect;   // [x, y, w, h] из jsonb
  final List<List<double>>? rawLabelPolygon;   // [[x,y],...] из jsonb

  /// Сколько полных циклов магазин недоступен после визита
  /// (shops.cooldown_cycles). Дефолт тот же, что у колонки в БД.
  final int cooldownCycles;

  Shop({
    required this.id,
    required this.name,
    required this.icon,
    required this.discount,
    this.shortDiscount = '',
    required this.description,
    required this.location,
    required this.category,
    required this.priority,
    required this.mallId,
    required this.imageUrl,
    this.infoImageUrl = '',
    this.mapX,
    this.mapY,
    this.mapWidth,
    this.mapHeight,
    this.imageTransform,
    this.infoImageTransform,
    this.rawMapPolygon,   // ← добавили
    this.entryX,          // ← добавили
    this.entryY,
    this.labelX,
    this.labelY,
    this.rawLabelAngle,
    this.rawLabelRect,
    this.rawLabelPolygon,
    this.cooldownCycles = 5,
  });

  factory Shop.fromSupabase(Map<String, dynamic> json) {
    double? parseCoord(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    return Shop(
      id: json['firestore_id'] as String,
      name: json['name'] ?? 'Без названия',
      icon: json['icon'] ?? '🛍️',
      discount: json['discount'] ?? '',
      shortDiscount: json['short_discount'] ?? '',
      description: json['description'] ?? '',
      location: json['location'] ?? '',
      category: json['category'] ?? 'other',
      priority: (json['priority'] as num?)?.toInt() ?? 1,
      mallId: json['mall_id'] ?? '',
      imageUrl: json['image_url'] ?? '',
      infoImageUrl: json['info_image_url'] ?? '',
      mapX: parseCoord(json['map_x']),
      mapY: parseCoord(json['map_y']),
      mapWidth: parseCoord(json['map_width']),
      mapHeight: parseCoord(json['map_height']),
      imageTransform: null,
      infoImageTransform: null,
      rawMapPolygon: json['map_polygon'] != null
    ? (json['map_polygon'] as List)
        .map((p) => (p as List).map((v) => (v as num).toDouble()).toList())
        .toList()
    : null,
      entryX: (json['entry_x'] as num?)?.toDouble(),
      entryY: (json['entry_y'] as num?)?.toDouble(),
      labelX: (json['label_x'] as num?)?.toDouble(),
      labelY: (json['label_y'] as num?)?.toDouble(),
      rawLabelAngle: (json['label_angle'] as num?)?.toDouble(),
      rawLabelRect: json['label_rect'] is List
          ? (json['label_rect'] as List)
              .whereType<num>()
              .map((v) => v.toDouble())
              .toList()
          : null,
      cooldownCycles: (json['cooldown_cycles'] as num?)?.toInt() ?? 5,
      rawLabelPolygon: json['label_polygon'] is List
          ? (json['label_polygon'] as List)
              .whereType<List>()
              .map((p) => p.whereType<num>().map((v) => v.toDouble()).toList())
              .toList()
          : null,
    );
  }
}

/// Акция магазина. Разделены по поводу визита: первый визит и повторный
/// (после отлёжки cooldown_cycles). Лежат в public.shop_promotions.
class ShopPromotion {
  final String id;
  final String shopId;

  /// 'first_visit' | 'repeat_visit'. Строкой, а не enum: значения приходят
  /// из БД, и неизвестный вид не должен ломать разбор строки.
  final String kind;

  final String title;
  final String shortDiscount;
  final String discount;
  final String description;
  final String? imageUrl;
  final int priority;
  final bool isActive;

  const ShopPromotion({
    required this.id,
    required this.shopId,
    required this.kind,
    this.title = '',
    this.shortDiscount = '',
    this.discount = '',
    this.description = '',
    this.imageUrl,
    this.priority = 0,
    this.isActive = true,
  });

  /// null, если строка без id/shop_id/kind — такую акцию не к чему
  /// привязать, и пусть лучше её не будет, чем полупустая.
  static ShopPromotion? fromSupabase(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final shopId = json['shop_id']?.toString();
    final kind = json['kind']?.toString();
    if (id == null || id.isEmpty) return null;
    if (shopId == null || shopId.isEmpty) return null;
    if (kind == null || kind.isEmpty) return null;

    return ShopPromotion(
      id: id,
      shopId: shopId,
      kind: kind,
      title: json['title']?.toString() ?? '',
      shortDiscount: json['short_discount']?.toString() ?? '',
      discount: json['discount']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      imageUrl: (json['image_url'] as String?)?.trim().isEmpty ?? true
          ? null
          : json['image_url'] as String?,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class BannerAd {
  final String id;
  final String title;
  final String description;
  final int color;
  final String targetShopId;
  final String discount;
  final String mallId;
  final String imageUrl;
  final List<double>? cropRectData;
  final int priority;
  final bool isActive;

  BannerAd({
    required this.id,
    required this.title,
    required this.description,
    required this.color,
    required this.targetShopId,
    required this.discount,
    required this.mallId,
    this.imageUrl = '',
    this.cropRectData,
    this.priority = 0,
    this.isActive = true,
  });

  factory BannerAd.fromSupabase(Map<String, dynamic> json) {
    int colorInt = 0xFF6C63FF;
    final rawColor = json['color'];
    if (rawColor is int) {
      colorInt = rawColor;
    } else if (rawColor is num) {
      colorInt = rawColor.toInt();
    } else if (rawColor is String) {
      final asDecimal = int.tryParse(rawColor);
      if (asDecimal != null) {
        colorInt = asDecimal;
      } else {
        final hex = rawColor.replaceAll('#', '');
        final parsed = int.tryParse(hex, radix: 16);
        if (parsed != null) {
          colorInt = hex.length == 6 ? 0xFF000000 | parsed : parsed;
        }
      }
    }

    final rawId = json['firestore_id'] ?? json['id'] ?? '';
    final id = rawId is String ? rawId : rawId.toString();

    return BannerAd(
      id: id,
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      color: colorInt,
      targetShopId: (json['target_shop_id'] as String?) ?? '',
      discount: (json['discount'] as String?) ?? '',
      mallId: (json['mall_id'] as String?) ?? '',
      imageUrl: (json['image_url'] as String?) ?? '',
      cropRectData: (json['crop_rect'] as List?)
          ?.whereType<num>()
          .map((e) => e.toDouble())
          .toList(),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }

  Rect? get cropRect {
    final data = cropRectData;
    if (data == null || data.length != 4) return null;
    return Rect.fromLTWH(data[0], data[1], data[2], data[3]);
  }
}