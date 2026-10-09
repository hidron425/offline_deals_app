// lib/shop_detail_screen.dart
//
// Карточка магазина на весь экран: сверху — кто это и какая скидка, снизу —
// план ТЦ с маршрутом от точки старта до этого магазина.
//
// Открывается из списка магазинов на вкладке «Карта». Тап по зоне на самой
// карте ведёт себя по-прежнему — показывает диалог (_showShopInfo), эта
// страница его не заменяет.

import 'package:flutter/material.dart';

import 'category_labels.dart';
import 'map/mall_map_widget.dart';
import 'models.dart';
import 'theme/app_theme.dart';

/// Откуда вести маршрут. Пока доступен только вход в ТЦ: геолокация внутри
/// помещения требует отдельной истории (Wi-Fi/BLE-позиционирование).
enum _StartChoice { entrance, myLocation }

class ShopDetailScreen extends StatefulWidget {
  final Shop shop;
  final String mapImageUrl;

  /// Все зоны ТЦ, а не только эта: MallMapWidget рисует план целиком,
  /// подсвечивая выбранный магазин.
  final List<MallStore> stores;

  final Offset entrancePosition;

  /// Реальная область плана внутри PNG. Значение привязано к текущему
  /// afimall.png — при замене картинки его нужно пересчитать.
  final Rect planBounds;

  final Set<String> visitedStoreIds;

  /// Запустить квест с этого магазина. null — баннер скидки не нажимается
  /// (например, если страницу открыли не из вкладки «Карта»).
  final void Function(Shop shop)? onStartQuestFromShop;

  const ShopDetailScreen({
    super.key,
    required this.shop,
    required this.mapImageUrl,
    required this.stores,
    required this.entrancePosition,
    required this.planBounds,
    this.visitedStoreIds = const <String>{},
    this.onStartQuestFromShop,
  });

  @override
  State<ShopDetailScreen> createState() => _ShopDetailScreenState();
}

class _ShopDetailScreenState extends State<ShopDetailScreen> {
  /// Точка, от которой считается маршрут. Пока всегда вход в ТЦ, но лежит
  /// в состоянии: кнопка «Изменить» уже умеет её переставлять.
  late Offset _startPoint;

  @override
  void initState() {
    super.initState();
    _startPoint = widget.entrancePosition;
  }

  String _startPointLabel() => 'входа в ТЦ';

  Future<void> _onStartQuestTapped() async {
    final cb = widget.onStartQuestFromShop;
    if (cb == null) return;
    // Сначала закрываем страницу магазина — иначе после переключения
    // вкладки она останется поверх списка.
    Navigator.of(context).pop();
    cb(widget.shop);
  }

  Future<void> _showChangeStartDialog() async {
    final result = await showDialog<_StartChoice>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Начало маршрута'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, _StartChoice.entrance),
            child: Row(children: const [
              Icon(Icons.door_front_door_outlined, size: 20),
              SizedBox(width: 12),
              Expanded(child: Text('От входа в ТЦ')),
            ]),
          ),
          // Вариант выключен: «от моего местоположения» требует навигации
          // внутри помещения, которой пока нет. Тап ничего не делает.
          SimpleDialogOption(
            onPressed: () {},
            child: Row(children: const [
              Icon(Icons.my_location, size: 20, color: AppColors.textDisabled),
              SizedBox(width: 12),
              Expanded(
                child: Text('От моего местоположения',
                    style: TextStyle(color: AppColors.textDisabled)),
              ),
              SizedBox(width: 8),
              Text('Скоро',
                  style: TextStyle(
                      color: AppColors.textDisabled,
                      fontSize: 11,
                      fontStyle: FontStyle.italic)),
            ]),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (result) {
      case _StartChoice.entrance:
        setState(() => _startPoint = widget.entrancePosition);
        break;
      case _StartChoice.myLocation:
        // Пока недостижимо: вариант в диалоге выключен. Ветка останется
        // здесь до появления позиционирования внутри помещения.
        break;
      case null:
        // Диалог закрыли мимо — точку старта не меняем.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = widget.shop;
    final hasDiscount =
        shop.shortDiscount.isNotEmpty || shop.discount.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(shop.name)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- кто это ---
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                // foregroundImage рисуется ПОВЕРХ child, и через
                // прозрачный фон логотипа просвечивает иконка-заглушка.
                // Поэтому либо иконка, либо картинка — но не вместе.
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.surfaceVariant,
                  child: shop.imageUrl.isEmpty
                      ? const Icon(Icons.store,
                          size: 28, color: AppColors.textSecondary)
                      : ClipOval(
                          child: Image.network(
                            shop.imageUrl,
                            width: 64,
                            height: 64,
                            // contain: у логотипов прозрачный фон, cover
                            // обрезал бы квадратные марки по краям.
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.store,
                              size: 28,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        categoryLabel(shop.category),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- скидка ---
          if (hasDiscount)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Material(
                color: AppColors.successContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  // Колбэка нет — баннер остаётся обычной плашкой без ink.
                  onTap: widget.onStartQuestFromShop == null
                      ? null
                      : _onStartQuestTapped,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (shop.shortDiscount.isNotEmpty)
                          Text(
                            shop.shortDiscount,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.success,
                            ),
                          ),
                        // Полную формулировку показываем, только если она
                        // не дублирует короткую.
                        if (shop.discount.isNotEmpty &&
                            shop.discount != shop.shortDiscount)
                          Text(
                            shop.discount,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textSecondary),
                          ),
                        if (widget.onStartQuestFromShop != null) ...[
                          const SizedBox(height: 6),
                          const Row(
                            children: [
                              Icon(Icons.play_arrow_rounded,
                                  size: 16, color: AppColors.success),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text('Начать квест с этого магазина',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.success,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // --- описание ---
          if (shop.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Text(
                shop.description,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ),

          // --- откуда ведём маршрут ---
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                const Icon(Icons.directions_walk_rounded, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Маршрут от: ${_startPointLabel()}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: _showChangeStartDialog,
                  child: const Text('Изменить'),
                ),
              ],
            ),
          ),

          // --- план с маршрутом ---
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: MallMapWidget(
                mapImageUrl: widget.mapImageUrl,
                stores: widget.stores,

                // Старт маршрута и маркер «вы здесь» — одна и та же точка.
                entrancePosition: _startPoint,

                // Страница всегда про один магазин: выбор не меняется.
                selectedStoreId: shop.id,
                visitedStoreIds: widget.visitedStoreIds,
                planBounds: widget.planBounds,

                interactive: true,
                autoFrame: true,
                showZoomControls: true,
                maxScale: 8.0,

                // Тап по другой зоне здесь ничего не делает: выбор
                // зафиксирован магазином страницы.
                onStoreSelected: null,
                onSelectionCleared: null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
