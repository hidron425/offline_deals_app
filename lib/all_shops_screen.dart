import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'category_labels.dart';
import 'models.dart';
import 'theme/app_theme.dart';
import 'widgets/app_widgets.dart';

class AllShopsScreen extends StatefulWidget {
  final void Function(Shop shop)? onStartQuest;
  final Set<String> visitedIds;
  final Map<String, int> visitedShopCycles;
  final int currentCycle;

  const AllShopsScreen({
    super.key,
    this.onStartQuest,
    this.visitedIds = const {},
    this.visitedShopCycles = const {},
    this.currentCycle = 0,
  });

  @override
  State<AllShopsScreen> createState() => _AllShopsScreenState();
}

class _AllShopsScreenState extends State<AllShopsScreen> {
  supa.SupabaseClient get _sb => supa.Supabase.instance.client;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedMallId;

  List<Shop> _allShops = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
    _loadShops();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadShops() async {
    try {
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
      _selectedMallId = mallId;

      var query = _sb.from('shops').select();
      if (mallId != null && mallId.isNotEmpty) {
        query = query.eq('mall_id', mallId);
      }
      final data = await query.order('name', ascending: true);
      final shops = (data as List)
          .map((json) => Shop.fromSupabase(Map<String, dynamic>.from(json)))
          .toList();

      if (mounted) {
        setState(() {
          _allShops = shops;
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

  List<Shop> _filteredShops() {
  return _allShops.where((s) {
    if (_searchQuery.isNotEmpty &&
        !s.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
      return false;
    }
    if (_selectedCategory != null &&
        s.category.toLowerCase() != _selectedCategory!.toLowerCase()) {
      return false;
    }
    return true;
  }).toList();
}

  List<String> _categories() {
    final cats = _allShops
        .map((s) => s.category)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    // Сортируем по подписи, а не по ключу из БД: иначе русские названия
    // идут в алфавите английских (cafe, clothing, electronics, other).
    cats.sort((a, b) => categoryLabel(a).compareTo(categoryLabel(b)));
    return cats;
  }

  void _showShopInfo(Shop shop) {
  final bool isVisited = widget.visitedIds.contains(shop.id);
  final infoImage =
      (shop.infoImageUrl.isNotEmpty) ? shop.infoImageUrl : shop.imageUrl;

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Center(
      child: FractionallySizedBox(
        widthFactor: 0.85,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (infoImage.isNotEmpty)
                  SizedBox(
                    height: 240,
                    child: Image.network(
                      infoImage,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.surfaceVariant,
                        alignment: Alignment.center,
                        child: Text(shop.icon,
                            style: const TextStyle(fontSize: 48)),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(shop.name, style: AppTextStyles.headline),
                      if (shop.description.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(shop.description,
                            style: AppTextStyles.bodyLarge),
                      ],
                      if (shop.discount.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.local_offer,
                                  color: AppColors.primary, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  shop.discount,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (shop.location.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 14,
                                color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(shop.location,
                                  style: AppTextStyles.caption),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),

                      // Если магазин уже посещён — показываем сообщение вместо кнопки старта
                      if (isVisited) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.check_circle,
                                      color: AppColors.success, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Уже посещён',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Вы уже посещали этот магазин в прошлом цикле. '
                                'Он снова станет доступен для прохождения '
                                'в следующих циклах.',
                                style: TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ] else if (widget.onStartQuest != null) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.pop(context);
                              widget.onStartQuest!.call(shop);
                            },
                            icon: const Icon(Icons.directions_walk),
                            label: const Text('Начать с этого магазина'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Закрыть'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Все магазины'),
        backgroundColor: AppColors.background,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Text('Ошибка: $_error'))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Поиск
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Поиск магазина',
                          prefixIcon: const Icon(Icons.search,
                              color: AppColors.textSecondary),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear,
                                      color: AppColors.textSecondary),
                                  onPressed: () =>
                                      _searchController.clear(),
                                )
                              : null,
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 0, horizontal: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Категории
                    if (_categories().isNotEmpty)
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: CategoryChip(
                                label: 'Все',
                                selected: _selectedCategory == null,
                                onTap: () => setState(
                                    () => _selectedCategory = null),
                              ),
                            ),
                            ..._categories().map((cat) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: CategoryChip(
                                    // Подпись переведённая, фильтр
                                    // _selectedCategory держит ключ из БД.
                                    label: categoryLabel(cat),
                                    selected: _selectedCategory == cat,
                                    onTap: () => setState(
                                        () => _selectedCategory = cat),
                                  ),
                                )),
                          ],
                        ),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    // Сетка магазинов
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final filtered = _filteredShops();
                          if (filtered.isEmpty) {
                            return const EmptyState(
                              icon: Icons.storefront_outlined,
                              title: 'Ничего не найдено',
                              subtitle: 'Измените запрос или категорию',
                            );
                          }
                          return GridView.builder(
  padding: const EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.sm,
  ),
  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 130,
    mainAxisSpacing: AppSpacing.md,
    crossAxisSpacing: AppSpacing.md,
    childAspectRatio: 0.62,
  ),
  itemCount: filtered.length,
  itemBuilder: (context, index) {
    final shop = filtered[index];
    // Оверлей «посещён» — по visitedIds: это множество реально приходит с
    // экрана квеста. visitedShopCycles/currentCycle на этом переходе не
    // передаются, поэтому isOnCooldown всегда был false и оверлей не
    // показывался вовсе. Поля оставляем: по ним будет подпись «доступен
    // с цикла N».
    final isVisited = widget.visitedIds.contains(shop.id);
    final visitCycle = widget.visitedShopCycles[shop.id];
    final isOnCooldown =
        visitCycle != null && widget.currentCycle <= visitCycle;
    final availableAtCycle = isOnCooldown ? visitCycle + 1 : null;

    return _ShopCard(
      shop: shop,
      onTap: () => _showShopInfo(shop),
      onHover: (_) {},
      isFavorite: false,
      onToggleFavorite: null,
      isVisited: isVisited,
      availableAtCycle: availableAtCycle,
    );
  },
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ----------------------------------------------------------------------
// Копия _ShopCard из main.dart — чтобы не экспортировать приватный класс
// ----------------------------------------------------------------------
  class _ShopCard extends StatefulWidget {
  final Shop shop;
  final VoidCallback onTap;
  final VoidCallback? onInfoTap;
  final ValueChanged<String?> onHover;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  final bool isVisited;
  final int? availableAtCycle;
  const _ShopCard({
    required this.shop,
    required this.onTap,
    this.onInfoTap,
    required this.onHover,
    this.isFavorite = false,
    this.onToggleFavorite,
    this.isVisited = false,
    this.availableAtCycle,
  });
  @override
  State<_ShopCard> createState() => _ShopCardState();
}

class _ShopCardState extends State<_ShopCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final String cardDiscount = widget.shop.shortDiscount.isNotEmpty
        ? widget.shop.shortDiscount
        : widget.shop.discount;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _isHovered = true);
        widget.onHover(widget.shop.id);
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        widget.onHover(null);
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: _isHovered
              ? Matrix4.translationValues(0, -4, 0)
              : Matrix4.identity(),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: widget.isFavorite
                      ? AppColors.accent.withOpacity(0.4)
                      : AppColors.border,
                  width: widget.isFavorite ? 1.5 : 1,
                ),
                boxShadow:
                    _isHovered ? AppShadows.cardHover : AppShadows.card,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Stack(
                  children: [
                    // ---------- Основное содержимое карточки ----------
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 90,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: AppColors.surface,
                                    border: Border(
                                      bottom: BorderSide(
                                        color: AppColors.border,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (widget.shop.imageUrl.isNotEmpty)
                                Positioned.fill(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Image.network(
                                      widget.shop.imageUrl,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error,
                                              stackTrace) =>
                                          Center(
                                        child: Text(
                                          widget.shop.icon,
                                          style: const TextStyle(
                                              fontSize: 40),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Center(
                                  child: Text(
                                    widget.shop.icon,
                                    style: const TextStyle(fontSize: 40),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 6),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.shop.name,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                    fontSize: 10,
                                    height: 1.1,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (cardDiscount.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.successContainer,
                                      borderRadius: BorderRadius.circular(
                                          AppRadius.pill),
                                    ),
                                    child: Text(
                                      cardDiscount,
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.success,
                                        height: 1.1,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                                      // ---------- Оверлей "Посещён" ----------
                  if (widget.isVisited)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          color: Colors.black.withOpacity(0.55),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Посещён',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Магазин будет доступен в следующих циклах',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      height: 1.15,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}