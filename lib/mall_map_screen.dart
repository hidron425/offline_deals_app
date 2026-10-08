// lib/mall_map_screen.dart
//
// Вкладка «Карта» в нижней навигации. Показывает тот же план ТЦ, что и
// превью на главной (MallMapWidget: контуры зон, подписи, вход, маршрут),
// но в интерактивном режиме — с панорамой, зумом и кнопками масштаба.
//
// План и точка входа берутся из public.malls выбранного пользователем ТЦ,
// а не из бандла: раньше здесь лежала картинка assets/images/mall_map.png,
// одна на все ТЦ.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import 'main.dart' show MainScreen;
import 'map/mall_map_widget.dart';
import 'map/shop_zone.dart';
import 'models.dart';

class MallMapScreen extends StatefulWidget {
  const MallMapScreen({super.key});

  @override
  State<MallMapScreen> createState() => _MallMapScreenState();
}

class _MallMapScreenState extends State<MallMapScreen> {
  /// Реальная область плана внутри PNG: строки 336..1183 из 1536 по высоте,
  /// вся ширина. Значение привязано к текущему afimall.png — при замене
  /// картинки его нужно пересчитать (такое же значение на главной).
  static const Rect _planBounds = Rect.fromLTRB(0.0, 0.22, 1.0, 0.77);

  bool _loading = true;
  String? _error;

  /// ТЦ не выбран — карту показывать нечему.
  bool _noMallSelected = false;

  String? _mapImageUrl;
  Offset _entrance = const Offset(0.5, 0.75);
  List<MallStore> _stores = const [];

  /// MallStore знает только id, имя и зону, а диалогу нужны описание и
  /// скидка — поэтому держим магазины по id.
  Map<String, Shop> _shopById = const {};

  String? _selectedStoreId;

  supa.SupabaseClient get _sb => supa.Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // --- загрузка -----------------------------------------------------------

  /// Вызывается, когда [_loading] уже true (из initState или из _retry).
  Future<void> _load() async {
    try {
      // 1. Какой ТЦ выбрал пользователь.
      final userId = _sb.auth.currentUser?.id;
      String? mallId;
      if (userId != null) {
        final progress = await _sb
            .from('user_progress')
            .select('selected_mall_id')
            .eq('user_id', userId)
            .maybeSingle();
        mallId = progress?['selected_mall_id'] as String?;
      }

      if (mallId == null || mallId.isEmpty) {
        // Раньше в этом случае молча рисовались магазины всех ТЦ на чужом
        // плане. Лучше честно попросить выбрать ТЦ.
        if (!mounted) return;
        setState(() {
          _noMallSelected = true;
          _loading = false;
        });
        return;
      }

      // 2. План этажа и вход.
      final mall = await _sb
          .from('malls')
          .select('map_image_url, entrance_x, entrance_y')
          .eq('firestore_id', mallId)
          .maybeSingle();

      // 3. Магазины этого ТЦ.
      final rows = await _sb.from('shops').select().eq('mall_id', mallId);
      final shops = (rows as List)
          .map((json) => Shop.fromSupabase(Map<String, dynamic>.from(json)))
          .toList();

      if (!mounted) return;
      setState(() {
        _mapImageUrl = mall?['map_image_url'] as String?;
        _entrance = Offset(
          (mall?['entrance_x'] as num?)?.toDouble() ?? 0.5,
          (mall?['entrance_y'] as num?)?.toDouble() ?? 0.75,
        );
        _stores = _buildStores(shops);
        _shopById = {for (final s in shops) s.id: s};
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ MallMapScreen._load: $e');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _retry() {
    setState(() {
      _loading = true;
      _error = null;
      _noMallSelected = false;
    });
    _load();
  }

  /// Та же логика, что в _buildEnhancedMap на главной: зона нужна целиком,
  /// иначе магазин на карту не попадает — ниже координаты разыменовываются.
  List<MallStore> _buildStores(List<Shop> shops) {
    final out = <MallStore>[];
    for (final s in shops) {
      if (s.mapX == null ||
          s.mapY == null ||
          s.mapWidth == null ||
          s.mapHeight == null ||
          s.mapWidth! <= 0 ||
          s.mapHeight! <= 0) {
        continue;
      }

      final entry = (s.entryX != null && s.entryY != null)
          ? Offset(s.entryX!, s.entryY!)
          : null;

      // Ручной якорь подписи: оба поля или ничего.
      final labelOverride = (s.labelX != null && s.labelY != null)
          ? Offset(s.labelX!, s.labelY!)
          : null;

      ShopZone? zone;
      final polygonRaw = s.rawMapPolygon;
      if (polygonRaw != null) {
        zone = ShopZone.fromDb({
          'map_polygon': polygonRaw,
          'entry_x': s.entryX,
          'entry_y': s.entryY,
          'label_x': s.labelX,
          'label_y': s.labelY,
          'label_angle': s.rawLabelAngle,
          'label_rect': s.rawLabelRect,
          'label_polygon': s.rawLabelPolygon,
        });
      }
      // Полигон битый или его нет — падаем назад на прямоугольник.
      zone ??= ShopZone.fromRect(
        ShopZone.clampRectToUnit(Rect.fromCenter(
          center: Offset(s.mapX!, s.mapY!),
          width: s.mapWidth!,
          height: s.mapHeight!,
        )),
        entry: entry,
        labelOverride: labelOverride,
        labelAngle: s.rawLabelAngle,
        labelRect: ShopZone.parseLabelRect(s.rawLabelRect),
        labelPolygon:
            ShopZone.readLabelPolygon({'label_polygon': s.rawLabelPolygon}),
      );

      out.add(MallStore(id: s.id, name: s.name, zone: zone));
    }
    return out;
  }

  // --- навигация ----------------------------------------------------------

  /// Переключает нижнюю навигацию на «Профиль».
  ///
  /// setTab живёт в приватном _MainScreenState из main.dart, поэтому
  /// статически он из этого файла не виден. Тип `State<MainScreen>`
  /// публичный — находим состояние по нему и зовём метод динамически.
  /// Если setTab переименуют, сломается здесь в рантайме.
  void _openProfileTab() {
    final state = context.findAncestorStateOfType<State<MainScreen>>();
    if (state == null) return;
    (state as dynamic).setTab(2);
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
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.green),
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

  // --- сборка -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Карта ТЦ')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_noMallSelected) {
      return _buildNotice(
        icon: Icons.store_mall_directory_outlined,
        text: 'Выберите торговый центр в профиле',
        action: ElevatedButton(
          onPressed: _openProfileTab,
          child: const Text('Открыть профиль'),
        ),
      );
    }
    if (_error != null) {
      return _buildNotice(
        icon: Icons.error_outline,
        text: 'Не удалось загрузить карту ТЦ',
        action: TextButton(onPressed: _retry, child: const Text('Повторить')),
      );
    }

    final url = _mapImageUrl;
    if (url == null || url.isEmpty) {
      return _buildNotice(
        icon: Icons.map_outlined,
        text: 'Карта ТЦ ещё не загружена',
        action: TextButton(onPressed: _retry, child: const Text('Повторить')),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: MallMapWidget(
        mapImageUrl: url,
        stores: _stores,
        entrancePosition: _entrance,
        planBounds: _planBounds,

        // Выбор магазина ведёт маршрут от входа; по умолчанию не выбран.
        selectedStoreId: _selectedStoreId,
        highlightedStoreIds: const <String>{},
        // Посещённые зоны живут в состоянии главного экрана; сюда их
        // прокинуть без общего хранилища нельзя.
        visitedStoreIds: const <String>{},

        // Полноэкранный режим: камерой управляет пользователь.
        interactive: true,
        autoFrame: false,
        showZoomControls: true,
        maxWidth: double.infinity,
        minScale: 1.0,
        // Тот же предел, что в редакторе зон (InteractiveViewer maxScale: 12
        // и зажим в _zoomAt). Иначе оператор размечает на зуме, недоступном
        // покупателю, и подписи у него выглядят иначе.
        maxScale: 12.0,

        // onPanLockChanged не нужен: родительского скролла на вкладке нет.
        onStoreSelected: (store) {
          setState(() => _selectedStoreId = store.id);
          final shop = _shopById[store.id];
          if (shop != null) _showShopInfo(shop);
        },
        onSelectionCleared: () => setState(() => _selectedStoreId = null),
      ),
    );
  }

  Widget _buildNotice({
    required IconData icon,
    required String text,
    required Widget action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xFF8A8F98)),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Color(0xFF5A606B)),
            ),
            const SizedBox(height: 8),
            action,
          ],
        ),
      ),
    );
  }
}
