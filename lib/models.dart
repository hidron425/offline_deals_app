import 'package:cloud_firestore/cloud_firestore.dart';

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
  final double? mapWidth;   // 🆕
  final double? mapHeight;  // 🆕

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
    );
  }
}

class BannerAd {
  final String title;
  final String description;
  final int color;
  final String targetShopId;
  final String discount;
  final String mallId;

  BannerAd({
    required this.title,
    required this.description,
    required this.color,
    required this.targetShopId,
    required this.discount,
    required this.mallId,
  });

  factory BannerAd.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    int colorInt = 0xFF6C63FF;
    final colorStr = data['color'] as String?;
    if (colorStr != null && colorStr.isNotEmpty) {
      final hexCode = colorStr.replaceAll('#', '');
      colorInt = int.parse(hexCode, radix: 16);
      if (hexCode.length == 6) colorInt = 0xFF000000 | colorInt;
    }
    return BannerAd(
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      color: colorInt,
      targetShopId: data['targetShopId'] ?? '',
      discount: data['discount'] ?? '',
      mallId: data['mallId'] ?? '',
    );
  }
}