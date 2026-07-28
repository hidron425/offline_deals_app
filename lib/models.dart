import 'package:cloud_firestore/cloud_firestore.dart';
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
  final List<double>? imageTransform;      // 16 чисел для логотипа
  final List<double>? infoImageTransform;  // 16 чисел для инфо-фото

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
  });

  factory Shop.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    double? parseCoord(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        return parsed;
      }
      return null;
    }

    List<double>? parseTransform(dynamic value) {
      if (value is List) {
        return value.map((e) => (e as num).toDouble()).toList();
      }
      return null;
    }

    return Shop(
      id: doc.id,
      name: data['name'] ?? 'Без названия',
      icon: data['icon'] ?? '🛍️',
      discount: data['discount'] ?? '',
      shortDiscount: data['shortDiscount'] ?? '',
      description: data['description'] ?? '',
      location: data['location'] ?? '',
      category: data['category'] ?? 'other',
      priority: (data['priority'] as int?) ?? 1,
      mallId: data['mallId'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      infoImageUrl: data['infoImageUrl'] ?? '',
      mapX: parseCoord(data['mapX']),
      mapY: parseCoord(data['mapY']),
      mapWidth: parseCoord(data['mapWidth']),
      mapHeight: parseCoord(data['mapHeight']),
      imageTransform: parseTransform(data['imageTransform']),
      infoImageTransform: parseTransform(data['infoImageTransform']),
    );
  }
}

class BannerAd {
  final String id;               // ID документа
  final String title;
  final String description;
  final int color;
  final String targetShopId;
  final String discount;
  final String mallId;
  final String imageUrl;
  final List<double>? cropRectData;   // [left, top, width, height]
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

  factory BannerAd.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Парсим цвет: может быть int или строка вида "#RRGGBB"
    int colorInt = 0xFF6C63FF;
    final rawColor = data['color'];
    if (rawColor is int) {
      colorInt = rawColor;
    } else if (rawColor is String) {
      final hex = rawColor.replaceAll('#', '');
      final parsed = int.tryParse(hex, radix: 16);
      if (parsed != null) {
        colorInt = hex.length == 6 ? 0xFF000000 | parsed : parsed;
      }
    }

    return BannerAd(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      color: colorInt,
      targetShopId: data['targetShopId'] as String? ?? '',
      discount: data['discount'] as String? ?? '',
      mallId: data['mallId'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      cropRectData: (data['cropRect'] as List?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      priority: (data['priority'] as num?)?.toInt() ?? 0,
      isActive: data['isActive'] as bool? ?? true,
    );
  }
/// Удобный геттер — возвращает Rect? из cropRectData
Rect? get cropRect {
  final data = cropRectData;
  if (data == null || data.length != 4) return null;
  return Rect.fromLTWH(data[0], data[1], data[2], data[3]);
}
}