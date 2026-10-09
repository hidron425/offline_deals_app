// lib/mall_map_screen.dart
//
// Вкладка «Карта» в нижней навигации. Показывает тот же план ТЦ, что и
// превью на главной (MallMapWidget: контуры зон, подписи, вход, маршрут),
// но в интерактивном режиме — с панорамой, зумом и кнопками масштаба.
//
// План и точка входа берутся из public.malls выбранного пользователем ТЦ,
// а не из бандла: раньше здесь лежала картинка assets/images/mall_map.png,
// одна на все ТЦ.
//
// Под планом — поиск, фильтр по категориям и список магазинов. Фильтры
// работают и на список, и на карту: совпадения подсвечиваются через
// highlightedStoreIds, остальные зоны гаснут.

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import 'category_labels.dart';
import 'main.dart' show MainScreen;
import 'map/mall_map_widget.dart';
import 'map/shop_zone.dart';
import 'models.dart';
import 'shop_detail_screen.dart';
import 'theme/app_theme.dart';

class MallMapScreen extends StatefulWidget {
  /// Запустить квест с этого магазина. Приходит из MainScreen: сама
  /// вкладка состоянием квеста не владеет.
  final void Function(Shop shop)? onStartQuestFromShop;

  /// Посещённые магазины. Множество принадлежит вкладке «Акции», сюда
  /// приходит только для чтения. null — подсветку посещённых не рисуем.
  final ValueListenable<Set<String>>? visitedStoreIds;

  const MallMapScreen({
    super.key,
    this.onStartQuestFromShop,
    this.visitedStoreIds,
  });

  @override
  State<MallMapScreen> createState() => _MallMapScreenState();
}

class _MallMapScreenState extends State<MallMapScreen> {
  /// Реальная область плана внутри PNG: строки 336..1183 из 1536 по высоте,
  /// вся ширина. Значение привязано к текущему afimall.png — при замене
  /// картинки его нужно пересчитать (такое же значение на главной).
  static const Rect _planBounds = Rect.fromLTRB(0.0, 0.22, 1.0, 0.77);

  /// Псевдокатегория «без фильтра». Не может совпасть с реальной: такого
  /// значения в shops.category нет.
  static const String _anyCategory = 'Все';

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

  /// Все магазины ТЦ по алфавиту — для списка и для набора категорий.
  /// Магазины без зоны тоже здесь: в списке они нужны, на карте их нет.
  List<Shop> _shops = const [];

  String? _selectedStoreId;

  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';
  String _category = _anyCategory;

  supa.SupabaseClient get _sb => supa.Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
        _shops = [...shops]..sort((a, b) => a.name.compareTo(b.name));
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

  // --- фильтры ------------------------------------------------------------

  /// «Все» + категории загруженных магазинов по алфавиту. Дедуп без учёта
  /// регистра: в базе встречаются и «Обувь», и «обувь».
  List<String> get _categories {
    final byLower = <String, String>{};
    for (final s in _shops) {
      final c = s.category.trim();
      if (c.isEmpty) continue;
      byLower.putIfAbsent(c.toLowerCase(), () => c);
    }
    final list = byLower.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [_anyCategory, ...list];
  }

  /// Поиск применяется ВНУТРИ выбранной категории, а не вместо неё.
  List<Shop> get _filteredShops {
    final query = _search.trim().toLowerCase();
    return _shops.where((s) {
      if (_category != _anyCategory &&
          s.category.toLowerCase() != _category.toLowerCase()) {
        return false;
      }
      return query.isEmpty || s.name.toLowerCase().contains(query);
    }).toList();
  }

  void _resetFilters() {
    _searchCtrl.clear();
    setState(() {
      _search = '';
      _category = _anyCategory;
    });
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

    final filtered = _filteredShops;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFilters(),
        if (filtered.isEmpty)
          Expanded(child: _buildNothingFound())
        else ...[
          Expanded(child: _buildMap(url, filtered)),
          _buildShopList(filtered),
        ],
      ],
    );
  }

  Widget _buildFilters() {
    // ВРЕМЕННО: диагностика «залипания» фильтров. Убрать после починки.
    debugPrint('[KARTA] buildFilters, _category=$_category, _search="$_search"');
    final categories = _categories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 12),
          child: TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            onChanged: (v) {
              // ВРЕМЕННО: диагностика. Убрать после починки.
              debugPrint('[KARTA] search onChanged: $v');
              setState(() => _search = v);
            },
            decoration: InputDecoration(
              hintText: 'Поиск магазина',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              filled: true,
              fillColor: AppColors.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide.none,
              ),
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Очистить',
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _search = '');
                      },
                    ),
            ),
          ),
        ),

        // Одна категория на весь ТЦ — выбирать не из чего, строку не рисуем.
        if (categories.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                for (final c in categories)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      // На чипе — перевод, в _category — английский ключ
                      // из БД: по нему и фильтруем.
                      label: Text(c == _anyCategory ? c : categoryLabel(c)),
                      // Выбор строго один: повторный тап по активному чипу
                      // возвращает «Все».
                      selected: _category == c,
                      onSelected: (_) {
                        // ВРЕМЕННО: диагностика. Убрать после починки.
                        debugPrint(
                            '[KARTA] chip tapped: $c, current _category=$_category');
                        setState(
                            () => _category = _category == c ? _anyCategory : c);
                      },
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  /// Карта. Параметры те же, что были до появления фильтров, — изменилась
  /// только подсветка: совпадения ярче, остальные зоны гаснут.
  Widget _buildMap(String url, List<Shop> filtered) {
    // Полный набор — это «фильтра нет», подсвечивать нечего.
    final highlighted = filtered.length == _shops.length
        ? const <String>{}
        : filtered.map((s) => s.id).toSet();

    // Посещённые приходят из вкладки «Акции» и меняются на ходу, поэтому
    // перестраиваем только карту, а не весь экран с фильтрами и списком.
    final visitedListenable = widget.visitedStoreIds;
    if (visitedListenable == null) {
      return _buildMapCard(url, highlighted, const <String>{});
    }
    return ValueListenableBuilder<Set<String>>(
      valueListenable: visitedListenable,
      builder: (context, visited, _) =>
          _buildMapCard(url, highlighted, visited),
    );
  }

  Widget _buildMapCard(
      String url, Set<String> highlighted, Set<String> visited) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: MallMapWidget(
        mapImageUrl: url,
        stores: _stores,
        entrancePosition: _entrance,
        planBounds: _planBounds,

        // Выбор магазина ведёт маршрут от входа; по умолчанию не выбран.
        selectedStoreId: _selectedStoreId,
        highlightedStoreIds: highlighted,
        visitedStoreIds: visited,

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

  /// Список под картой. Отметки «посещён» приходят из вкладки «Акции» и
  /// меняются на ходу, поэтому слушаем нотифаер здесь же — перестраивается
  /// только список, а не фильтры и не карта (тот же приём, что в _buildMap).
  Widget _buildShopList(List<Shop> shops) {
    final visitedListenable = widget.visitedStoreIds;
    if (visitedListenable == null) {
      return _buildShopListBody(shops, const <String>{});
    }
    return ValueListenableBuilder<Set<String>>(
      valueListenable: visitedListenable,
      builder: (context, visited, _) => _buildShopListBody(shops, visited),
    );
  }

  /// Высота — 30% экрана, но не больше 240: на вытянутом экране список не
  /// должен съедать план.
  Widget _buildShopListBody(List<Shop> shops, Set<String> visited) {
    final height =
        math.min(MediaQuery.of(context).size.height * 0.3, 240.0);

    // Material, а не просто Container с цветом: без Material-предка
    // ListTile не может нарисовать ни фон выделения, ни ink-всплеск
    // (в консоли — «background color or ink splashes may be invisible»).
    return Material(
      color: AppColors.surface,
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          itemCount: shops.length,
          separatorBuilder: (_, _) => const Divider(
            height: 1,
            indent: AppSpacing.md,
            endIndent: AppSpacing.md,
          ),
          itemBuilder: (context, index) {
            final shop = shops[index];
            // В карточке магазина коротая скидка информативнее полной.
            final subtitle = shop.shortDiscount.isNotEmpty
                ? shop.shortDiscount
                : shop.discount;

            return ListTile(
              dense: true,
              selected: shop.id == _selectedStoreId,
              selectedTileColor: AppColors.primaryContainer,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              // foregroundImage здесь не годится: он рисуется ПОВЕРХ child,
              // и через прозрачный фон логотипа просвечивает иконка-заглушка.
              // Поэтому либо иконка, либо картинка — но не вместе.
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.surfaceVariant,
                child: shop.imageUrl.isEmpty
                    ? const Icon(Icons.store,
                        size: 18, color: AppColors.textSecondary)
                    : ClipOval(
                        child: Image.network(
                          shop.imageUrl,
                          width: 36,
                          height: 36,
                          // contain, а не cover: у логотипов прозрачный фон,
                          // и cover обрезал бы квадратные марки по краям.
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.store,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
              ),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Flexible, иначе длинное название вытолкнет галочку за
                  // край строки вместо того, чтобы обрезаться троеточием.
                  Flexible(
                    child: Text(
                      shop.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (visited.contains(shop.id))
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.check_circle,
                          size: 14, color: AppColors.success),
                    ),
                ],
              ),
              subtitle: subtitle.isEmpty
                  ? null
                  : Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
              // Тап строки открывает карточку магазина с маршрутом. Диалог
              // _showShopInfo остаётся на тапе по зоне самой карты.
              onTap: () => _openShopDetail(shop),
            );
          },
        ),
      ),
    );
  }

  void _openShopDetail(Shop shop) {
    final url = _mapImageUrl;
    if (url == null || url.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShopDetailScreen(
          shop: shop,
          mapImageUrl: url,
          stores: _stores,
          entrancePosition: _entrance,
          planBounds: _planBounds,
          // Снимок на момент открытия: страница магазина живёт недолго и
          // пересчитывать посещённые на ходу ей не нужно.
          visitedStoreIds: widget.visitedStoreIds?.value ?? const <String>{},
          onStartQuestFromShop: widget.onStartQuestFromShop,
        ),
      ),
    );
  }

  Widget _buildNothingFound() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off,
                size: 48, color: AppColors.textDisabled),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Ничего не найдено',
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: _resetFilters,
              child: const Text('Сбросить фильтры'),
            ),
          ],
        ),
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
