import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models.dart';

class MallMapScreen extends StatefulWidget {
  const MallMapScreen({super.key});

  @override
  State<MallMapScreen> createState() => _MallMapScreenState();
}

class _MallMapScreenState extends State<MallMapScreen> {
  final TransformationController _transformController = TransformationController();
  List<Shop> _shops = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  Future<void> _loadShops() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('shops').get();
      final shops = snapshot.docs.map((doc) => Shop.fromFirestore(doc)).toList();
      if (mounted) {
        setState(() {
          _shops = shops;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _showShopInfo(Shop shop) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(shop.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (shop.description.isNotEmpty) Text(shop.description),
            if (shop.discount.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(shop.discount,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.green)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(child: Text('Ошибка загрузки карты: $_error')),
      );
    }

    // Отфильтруем магазины с корректными координатами
    final validShops = _shops.where((s) => s.mapX != null && s.mapY != null).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Карта ТЦ')),
      body: InteractiveViewer(
        transformationController: _transformController,
        minScale: 0.5,
        maxScale: 3.0,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Image.asset(
                  'assets/images/mall_map.png',
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  fit: BoxFit.contain,
                ),
                ...validShops.map((shop) {
                  final double x = shop.mapX! * constraints.maxWidth;
                  final double y = shop.mapY! * constraints.maxHeight;
                  return Positioned(
                    left: x - 15,
                    top: y - 15,
                    child: GestureDetector(
                      onTap: () => _showShopInfo(shop),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withOpacity(0.8),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Center(
                          child: Text(shop.icon,
                              style: const TextStyle(fontSize: 14)),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            );
          },
        ),
      ),
    );
  }
}