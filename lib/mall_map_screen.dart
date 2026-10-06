import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
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

  supa.SupabaseClient get _sb => supa.Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  Future<void> _loadShops() async {
    try {
      // Получаем выбранный ТЦ пользователя
      final userId = supa.Supabase.instance.client.auth.currentUser?.id;
      String? mallId;

      if (userId != null) {
        final data = await _sb
            .from('user_progress')
            .select('selected_mall_id')
            .eq('user_id', userId)
            .maybeSingle();
        mallId = data?['selected_mall_id'] as String?;
      }

      // Читаем магазины: все или только выбранного ТЦ
      var query = _sb.from('shops').select();
      if (mallId != null && mallId.isNotEmpty) {
        query = query.eq('mall_id', mallId);
      }

      final data = await query;
      final shops = (data as List)
          .map((json) => Shop.fromSupabase(Map<String, dynamic>.from(json)))
          .toList();

      if (mounted) {
        setState(() {
          _shops = shops;
          _loading = false;
        });
      }
    } catch (e) {
      print('❌ _loadShops (mall_map): $e');
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
                child: Text(
                  shop.discount,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                ),
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

    final validShops = _shops.where((s) => s.mapX != null && s.mapY != null).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Карта ТЦ')),
      body: InteractiveViewer(
        transformationController: _transformController,
        minScale: 0.5,
        maxScale: 3.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: Center(
            child: AspectRatio(
              aspectRatio: 2700 / 1536,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      Image.asset(
                        'assets/images/mall_map.png',
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        fit: BoxFit.fill,
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
                                child: Text(shop.icon, style: const TextStyle(fontSize: 14)),
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
          ),
        ),
      ),
    );
  }
}