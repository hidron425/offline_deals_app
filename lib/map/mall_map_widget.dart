// lib/map/mall_map_widget.dart
//
// Клиентская карта ТЦ. Зоны магазинов — произвольные контуры (прямоугольник
// это просто контур из 4 вершин, см. ShopZone), маршрут от входа в ТЦ идёт
// к двери магазина, если она задана, иначе к визуальному центру зоны.
//
// Два режима использования:
//   • interactive: true  — полноэкранная карта на вкладке «Карта»
//   • interactive: false — превью на главной. Без зума, с авто-кадром на
//     маршрут «вы → выбранный магазин», тап открывает полную карту.

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'shop_zone.dart';

@immutable
class MallStore {
  final String id;
  final String name;
  final ShopZone zone;

  const MallStore({required this.id, required this.name, required this.zone});
}

@immutable
class MallMapStyle {
  final Color zoneIdle;
  final Color zoneSelected;
  final Color zoneBorder;
  final Color zoneVisited;
  final Color zoneHighlighted;
  final Color highlightBorder;
  final Color route;
  final Color userMarker;
  final Color destinationMarker;
  final Color surface;
  final Color border;

  const MallMapStyle({
    this.zoneIdle = const Color(0x1A1E5AFF),
    this.zoneSelected = const Color(0x661E5AFF),
    this.zoneBorder = const Color(0xFF1E5AFF),
    this.zoneVisited = const Color(0x2616A34A),
    this.zoneHighlighted = const Color(0x4DFF6B35),
    this.highlightBorder = const Color(0xFFFF6B35),
    this.route = const Color(0xFFFF6B35),
    this.userMarker = const Color(0xFF1E5AFF),
    this.destinationMarker = const Color(0xFFFF6B35),
    this.surface = const Color(0xFFF5F6F8),
    this.border = const Color(0xFFE2E5EA),
  });
}

enum MallRouteShape { direct, elbow }

class MallMapWidget extends StatefulWidget {
  final String mapImageUrl;
  final List<MallStore> stores;

  final Offset entrancePosition;
  final Offset? userPosition;

  final String? selectedStoreId;

  /// Магазины, которые нужно подсветить отдельным цветом — например,
  /// два варианта развилки при нажатии «Продолжить позже».
  final Set<String> highlightedStoreIds;

  final ValueChanged<MallStore>? onStoreSelected;
  final VoidCallback? onSelectionCleared;

  final Set<String> visitedStoreIds;
  final ValueChanged<bool>? onPanLockChanged;

  /// Реальная область плана внутри PNG, в нормализованных координатах.
  ///
  /// Картинка обычно больше самого плана: у afimall.png низ — пустое поле.
  /// Если область задана, камера авто-кадра упирается в ЕЁ границы, а не в
  /// границы файла, поэтому пустые поля не попадают в карточку. null —
  /// упираемся в края PNG (0..1), как было.
  ///
  /// Значение зависит от конкретной картинки: при замене плана его нужно
  /// пересчитать. Координаты магазинов в БД оно не затрагивает.
  final Rect? planBounds;

  final double maxWidth;
  final double minScale;
  final double maxScale;
  final bool showRoute;
  final MallRouteShape routeShape;
  final double fallbackAspectRatio;
  final MallMapStyle style;

  // --- Превью-режим (главная страница) ---
  /// Разрешить зум и панораму. На главной — false.
  final bool interactive;

  /// Автоматически приближать вид к маршруту «вход → выбранный магазин».
  final bool autoFrame;

  /// Показывать кнопки +/−/fit. На главной — false.
  final bool showZoomControls;

  /// Фиксированная высота карточки. Если null — считается по aspect ratio.
  final double? height;

  /// Что делать при тапе по карте. Если задан — вместо выбора магазина
  /// вызывается этот колбэк (например, открытие полной карты).
  final VoidCallback? onTapMap;

  const MallMapWidget({
    super.key,
    required this.mapImageUrl,
    required this.stores,
    this.entrancePosition = const Offset(0.5, 0.8),
    this.userPosition,
    this.selectedStoreId,
    this.highlightedStoreIds = const {},
    this.onStoreSelected,
    this.onSelectionCleared,
    this.visitedStoreIds = const {},
    this.onPanLockChanged,
    this.planBounds,
    this.maxWidth = 1000,
    this.minScale = 1.0,
    this.maxScale = 4.0,
    this.showRoute = true,
    this.routeShape = MallRouteShape.elbow,
    this.fallbackAspectRatio = 2700 / 1536,
    this.style = const MallMapStyle(),
    this.interactive = true,
    this.autoFrame = false,
    this.showZoomControls = true,
    this.height,
    this.onTapMap,
  });

  @override
  State<MallMapWidget> createState() => _MallMapWidgetState();
}

class _MallMapWidgetState extends State<MallMapWidget>
    with TickerProviderStateMixin {
  static const double _tapTolerance = 8;

  /// Высота булавки маркера: она рисуется НАД точкой, поэтому при
  /// кадрировании сверху нужен запас, иначе маркер срежется краем карточки.
  static const double _markerHeight = 44;

  /// Зум превью, когда магазин не выбран. Карточка должна отвечать на
  /// вопрос «откуда я начинаю и что рядом», а не показывать весь план:
  /// весь план — это вкладка «Карта».
  static const double _entranceZoom = 2.0;

  static const Rect _unitRect = Rect.fromLTRB(0, 0, 1, 1);

  final TransformationController _controller = TransformationController();
  late final AnimationController _pulse;

  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  Size? _imageSize;
  Object? _imageError;

  double _scale = 1.0;
  bool _panLocked = false;
  bool _wheelZoomArmed = false;

  /// Кэш последнего авто-кадра: если ничего значимого не менялось —
  /// матрицу не трогаем, чтобы не сбивать ручной зум пользователя.
  String? _lastFrameKey;

  /// Размер холста из последнего layout — нужен для отложенного авто-кадра.
  Size _lastCanvasSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _controller.addListener(_onTransformChanged);
    _resolveImageSize();
  }

  @override
  void didUpdateWidget(covariant MallMapWidget old) {
    super.didUpdateWidget(old);
    if (old.mapImageUrl != widget.mapImageUrl) {
      _imageSize = null;
      _imageError = null;
      _lastFrameKey = null;
      _resolveImageSize();
    }
    // Сменилась цель маршрута, развилка или точка старта — пересчитать кадр
    // превью. Список магазинов пересобирается на каждый build родителя,
    // поэтому в условие он не входит: смена состава зон меняет размер
    // холста, а это уже ловится в build.
    //
    // Set не переопределяет ==, а родитель каждый build создаёт новый,
    // поэтому сравниваем по содержимому: иначе кадр пересчитывался бы
    // на каждую перерисовку.
    final highlightChanged = old.highlightedStoreIds.length !=
            widget.highlightedStoreIds.length ||
        !old.highlightedStoreIds.containsAll(widget.highlightedStoreIds);

    if (old.selectedStoreId != widget.selectedStoreId ||
        old.entrancePosition != widget.entrancePosition ||
        old.userPosition != widget.userPosition ||
        old.planBounds != widget.planBounds ||
        highlightChanged) {
      _lastFrameKey = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyAutoFrame(_lastCanvasSize);
      });
    }
  }

  @override
  void dispose() {
    _detachImageListener();
    _controller.removeListener(_onTransformChanged);
    _controller.dispose();
    _pulse.dispose();
    super.dispose();
  }

  // --- размер изображения -----------------------------------------------

  void _resolveImageSize() {
    _detachImageListener();
    final stream =
        NetworkImage(widget.mapImageUrl).resolve(const ImageConfiguration());
    final listener = ImageStreamListener(
      (info, _) {
        if (!mounted) return;
        setState(() => _imageSize =
            Size(info.image.width.toDouble(), info.image.height.toDouble()));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _applyAutoFrame(_lastCanvasSize);
        });
      },
      onError: (error, _) {
        if (!mounted) return;
        setState(() => _imageError = error);
      },
    );
    stream.addListener(listener);
    _imageStream = stream;
    _imageListener = listener;
  }

  void _detachImageListener() {
    if (_imageStream != null && _imageListener != null) {
      _imageStream!.removeListener(_imageListener!);
    }
    _imageStream = null;
    _imageListener = null;
  }

  double get _aspectRatio => (_imageSize != null && _imageSize!.height > 0)
      ? _imageSize!.width / _imageSize!.height
      : widget.fallbackAspectRatio;

  // --- трансформация ------------------------------------------------------

  void _onTransformChanged() {
    final scale = _controller.value.getMaxScaleOnAxis();
    if ((scale - _scale).abs() < 0.001) return;
    setState(() => _scale = scale);
    final locked = scale > 1.01;
    if (locked != _panLocked) {
      _panLocked = locked;
      widget.onPanLockChanged?.call(locked);
    }
  }

  void _zoomBy(double factor, Size viewport) {
    if (!widget.interactive) return;
    final current = _controller.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(widget.minScale, widget.maxScale);
    if (next == current) return;
    if (next <= widget.minScale) {
      _controller.value = Matrix4.identity();
      return;
    }
    final focal = Offset(viewport.width / 2, viewport.height / 2);
    final m = _controller.value;
    final translation = Offset(m.storage[12], m.storage[13]);
    final contentPoint = (focal - translation) / current;
    _controller.value = Matrix4.identity()
      ..translate(focal.dx - contentPoint.dx * next,
          focal.dy - contentPoint.dy * next)
      ..scale(next);
  }

  void _resetZoom() {
    if (!widget.interactive) return;
    _controller.value = Matrix4.identity();
  }

  /// [MallMapWidget.planBounds], приведённый к 0..1. Если не задан или
  /// задан мусором (перевёрнутый прямоугольник после замены картинки) —
  /// берём весь файл, то есть ведём себя как раньше.
  Rect get _effectivePlanBounds {
    final b = widget.planBounds;
    if (b == null) return _unitRect;
    final r = Rect.fromLTRB(
      b.left.clamp(0.0, 1.0),
      b.top.clamp(0.0, 1.0),
      b.right.clamp(0.0, 1.0),
      b.bottom.clamp(0.0, 1.0),
    );
    if (r.width <= 0 || r.height <= 0) return _unitRect;
    return r;
  }

  /// Сдвиг по одной оси: цель в центре карточки, но камера не выходит за
  /// пределы плана. [contentMin]/[contentMax] — границы плана по этой оси
  /// в координатах экрана (уже с учётом зума): для planBounds это его края,
  /// иначе — края PNG. Если план по этой оси короче карточки, центрируем
  /// его целиком, остаток закрывает фон карточки.
  static double _frameOffset(
      double cardLen, double contentMin, double contentMax, double target) {
    if (contentMax - contentMin <= cardLen) {
      return cardLen / 2 - (contentMin + contentMax) / 2;
    }
    return (cardLen / 2 - target).clamp(cardLen - contentMax, -contentMin);
  }

  /// Цели подсвеченных магазинов (две ветки развилки) в координатах холста.
  /// id, которых нет в [MallMapWidget.stores], пропускаем.
  List<Offset> _highlightedDestinations(Size canvas) {
    if (widget.highlightedStoreIds.isEmpty) return const [];
    return [
      for (final store in widget.stores)
        if (widget.highlightedStoreIds.contains(store.id))
          _toCanvas(store.zone.destination, canvas),
    ];
  }

  /// Кадр по набору точек: их bbox плюс запас, и зум «чтобы влезло целиком».
  /// Одна формула и для маршрута, и для развилки — чтобы они не разъехались.
  ({double scale, Offset target}) _frameForPoints(
      List<Offset> points, Size canvas) {
    var box = Rect.fromPoints(points.first, points.first);
    for (final p in points.skip(1)) {
      box = box.expandToInclude(Rect.fromPoints(p, p));
    }

    final pad = math.max(40.0, math.max(box.width, box.height) * 0.25);
    // Сверху запас больше: булавка маркера рисуется НАД точкой.
    final frame = Rect.fromLTRB(
      box.left - pad,
      box.top - pad - _markerHeight,
      box.right + pad,
      box.bottom + pad,
    ).intersect(Offset.zero & canvas);

    // Кадр обрезан по холсту, поэтому масштаб «чтобы влез целиком»
    // всегда >= 1: все точки гарантированно в кадре.
    final double scale = math
        .min(canvas.width / math.max(frame.width, 1.0),
            canvas.height / math.max(frame.height, 1.0))
        .clamp(widget.minScale, math.min(3.0, widget.maxScale))
        .toDouble();
    return (scale: scale, target: frame.center);
  }

  /// Кадрирует превью. Три случая, в порядке приоритета:
  ///
  ///   1. Открыта развилка (есть highlightedStoreIds) — в кадре вход и ОБА
  ///      варианта: выбор важнее заполнения карточки, поэтому зум может
  ///      упасть почти до 1.0 и показать больше плана.
  ///   2. Выбран магазин — показываем маршрут: вход и дверь магазина.
  ///   3. Ничего не выбрано — центр на входе с фиксированным зумом
  ///      [_entranceZoom]: превью отвечает «откуда я начинаю и что рядом».
  void _applyAutoFrame(Size canvas) {
    if (!widget.autoFrame || canvas.isEmpty) return;

    final entrance = widget.userPosition ?? widget.entrancePosition;
    final selected = _selectedStore;
    final highlighted = _highlightedDestinations(canvas);

    final highlightKey = (widget.highlightedStoreIds.toList()..sort()).join(',');
    final key = '${widget.mapImageUrl}|${selected?.id ?? "none"}'
        '|$highlightKey'
        '|${canvas.width.round()}x${canvas.height.round()}'
        '|${entrance.dx.toStringAsFixed(3)},${entrance.dy.toStringAsFixed(3)}';
    if (key == _lastFrameKey) return;
    _lastFrameKey = key;

    final double scale;
    final Offset target;
    if (highlighted.isNotEmpty) {
      // Развилка. С одной найденной зоной bbox совпадает с маршрутным —
      // формула та же, поэтому отдельный случай не нужен.
      final frame = _frameForPoints(
        [_toCanvas(entrance, canvas), ...highlighted],
        canvas,
      );
      scale = frame.scale;
      target = frame.target;
    } else if (selected == null) {
      scale = _entranceZoom.clamp(widget.minScale, widget.maxScale);
      target = _toCanvas(entrance, canvas);
    } else {
      final frame = _frameForPoints(
        [
          _toCanvas(entrance, canvas),
          _toCanvas(selected.zone.destination, canvas),
        ],
        canvas,
      );
      scale = frame.scale;
      target = frame.target;
    }

    // Границы плана на экране: по ним камера и упирается.
    final plan = _effectivePlanBounds;
    _controller.value = Matrix4.identity()
      ..translate(
        _frameOffset(
          canvas.width,
          plan.left * canvas.width * scale,
          plan.right * canvas.width * scale,
          target.dx * scale,
        ),
        _frameOffset(
          canvas.height,
          plan.top * canvas.height * scale,
          plan.bottom * canvas.height * scale,
          target.dy * scale,
        ),
      )
      ..scale(scale);
  }

  // --- данные -------------------------------------------------------------

  MallStore? get _selectedStore {
    if (widget.selectedStoreId == null) return null;
    for (final s in widget.stores) {
      if (s.id == widget.selectedStoreId) return s;
    }
    return null;
  }

  List<MallStore> get _hitOrder {
    final list = [...widget.stores]
      ..sort((a, b) => a.zone.area.compareTo(b.zone.area));
    return list;
  }

  MallStore? _storeAt(Offset local, Size canvas) {
    final tolerance = _tapTolerance / _scale;
    for (final store in _hitOrder) {
      final pts = store.zone.canvasPoints(canvas);
      if (PolygonMath.contains(pts, local, edgeTolerance: tolerance)) {
        return store;
      }
    }
    return null;
  }

  // --- сборка -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = math.min(
          constraints.maxWidth.isFinite ? constraints.maxWidth : widget.maxWidth,
          widget.maxWidth,
        );
        final maxH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : double.infinity;

        // Холст совпадает с карточкой: height, если задана, иначе высота
        // по пропорциям плана. Кадрированием занимается _applyAutoFrame.
        //
        // Высоту считаем от ширины, но не даём ей превысить то, что дал
        // родитель. Иначе при открытой клавиатуре слот сжимается, Container
        // зажимается констрейнтами до реальной высоты, а canvas остаётся
        // прежней — и _MapPainter рисует зоны по одной геометрии, а
        // картинка вписывается в другую. Ниже всё — отрисовка, хит-тест,
        // _toCanvas, авто-кадр — считает от ЭТОГО значения.
        final natural = widget.height ?? maxW / _aspectRatio;
        final canvasH = math.min(natural, maxH);
        final canvas = Size(maxW, canvasH);

        // Размер поменялся (поворот, ресайз окна) — кадр пересчитываем.
        // Ручной зум не сбрасываем: ключ внутри _applyAutoFrame не
        // изменится, если ничего значимого не менялось.
        if (canvas != _lastCanvasSize) {
          _lastCanvasSize = canvas;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _applyAutoFrame(_lastCanvasSize);
          });
        }

        return Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: canvas.width,
              height: canvas.height,
              decoration: BoxDecoration(
                color: widget.style.surface,
                border: Border.all(color: widget.style.border),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  Positioned.fill(child: _buildViewer(canvas)),
                  if (widget.showZoomControls)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: _buildZoomControls(canvas),
                    ),
                  if (kIsWeb && !_wheelZoomArmed && widget.interactive)
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: _buildHint('Нажмите на карту, чтобы приближать'),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildViewer(Size canvas) {
    if (_imageError != null) return _buildImageError();

    final selected = _selectedStore;
    final userPoint =
        _toCanvas(widget.userPosition ?? widget.entrancePosition, canvas);

    // Считаем один раз: нужен только слою маршрута.
    final routePoints = (widget.showRoute && selected != null)
        ? _routeWaypoints(
            userPoint,
            _toCanvas(selected.zone.destination, canvas),
          )
        : null;

    final content = SizedBox(
      width: canvas.width,
      height: canvas.height,
      child: Stack(
        children: [
          // 1. План этажа
          Positioned.fill(
            child: Image.network(
              widget.mapImageUrl,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => _buildImageError(),
            ),
          ),

          // 2. Зоны и подписи — статический слой. Перерисовывается только
          //    когда реально меняются его входные данные.
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _MapPainter(
                  stores: widget.stores,
                  selectedId: widget.selectedStoreId,
                  visitedIds: widget.visitedStoreIds,
                  highlightedIds: widget.highlightedStoreIds,
                  style: widget.style,
                  scale: _scale,
                ),
              ),
            ),
          ),

          // 3. Маршрут — отдельный слой, он один анимируется пульсом.
          //    Порядок тот же, что раньше внутри одного paint(): маршрут
          //    поверх зон и подписей, но под маркерами.
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _RoutePainter(
                  route: routePoints,
                  scale: _scale,
                  routeColor: widget.style.route,
                  animation: _pulse,
                ),
              ),
            ),
          ),

          // Семантика для screen reader'ов
          ...widget.stores.map((store) {
            final b = store.zone.bounds;
            return Positioned(
              left: b.left * canvas.width,
              top: b.top * canvas.height,
              width: b.width * canvas.width,
              height: b.height * canvas.height,
              child: Semantics(
                button: true,
                label: store.name,
                onTap: () => widget.onStoreSelected?.call(store),
                child: const SizedBox.expand(),
              ),
            );
          }),

          // Слой жестов: без hover, с поддержкой onTapMap.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                // Превью: тап по карте открывает полную карту.
                if (widget.onTapMap != null) {
                  widget.onTapMap!();
                  return;
                }
                if (kIsWeb && !_wheelZoomArmed) {
                  setState(() => _wheelZoomArmed = true);
                }
                final store = _storeAt(details.localPosition, canvas);
                store != null
                    ? widget.onStoreSelected?.call(store)
                    : widget.onSelectionCleared?.call();
              },
            ),
          ),

          // 4. Маркеры
          if (selected != null)
            _buildMarker(
              point: _toCanvas(selected.zone.destination, canvas),
              icon: Icons.flag_rounded,
              color: widget.style.destinationMarker,
              tooltip: selected.name,
            ),
          _buildUserHalo(userPoint),
          _buildMarker(
            point: userPoint,
            icon: Icons.directions_walk_rounded,
            color: widget.style.userMarker,
            tooltip: 'Вы здесь',
          ),
        ],
      ),
    );

    // Превью: InteractiveViewer не ставим вовсе. Даже с panEnabled: false
    // он забирает вертикальный drag, и родительский SingleChildScrollView
    // не может продолжить скролл за карточкой — страница «залипает».
    //
    // Матрицу при этом применяем сами: кадрированием превью занимается
    // _applyAutoFrame, и без неё карточка показала бы весь PNG без зума, да
    // ещё с подписями, посчитанными на _scale от кадра. Тап по карте ловит
    // GestureDetector внутри Stack (onTapMap) — он остаётся на месте.
    if (!widget.interactive) {
      return ClipRect(
        child: ValueListenableBuilder<Matrix4>(
          valueListenable: _controller,
          builder: (context, matrix, child) =>
              Transform(transform: matrix, child: child),
          child: content,
        ),
      );
    }

    // Интерактив: пользователь сам рулит камерой. Проверки на
    // widget.interactive в panEnabled/scaleEnabled больше не нужны —
    // до этой строки доходит только интерактивный режим.
    return InteractiveViewer(
      transformationController: _controller,
      minScale: widget.minScale,
      maxScale: widget.maxScale,
      panEnabled: _scale > 1.01,
      scaleEnabled: !kIsWeb || _wheelZoomArmed || _scale > 1.01,
      clipBehavior: Clip.hardEdge,
      child: content,
    );
  }

  Offset _toCanvas(Offset n, Size canvas) => Offset(
        n.dx.clamp(0.0, 1.0) * canvas.width,
        n.dy.clamp(0.0, 1.0) * canvas.height,
      );

  List<Offset> _routeWaypoints(Offset from, Offset to) {
    if (widget.routeShape == MallRouteShape.direct) return [from, to];
    final dx = (to.dx - from.dx).abs();
    final dy = (to.dy - from.dy).abs();
    final elbow = dy >= dx ? Offset(from.dx, to.dy) : Offset(to.dx, from.dy);
    if ((elbow - from).distance < 1 || (elbow - to).distance < 1) {
      return [from, to];
    }
    return [from, elbow, to];
  }

  // --- маркеры ------------------------------------------------------------

  Widget _buildMarker({
    required Offset point,
    required IconData icon,
    required Color color,
    required String tooltip,
  }) {
    const double w = 34;
    const double h = 44;
    return Positioned(
      left: point.dx - w / 2,
      top: point.dy - h,
      width: w,
      height: h,
      child: IgnorePointer(
        child: Transform.scale(
          scale: 1 / _scale,
          alignment: Alignment.bottomCenter,
          child: Tooltip(
            message: tooltip,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: w,
                  height: w,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 17, color: Colors.white),
                ),
                CustomPaint(
                  size: const Size(12, h - w),
                  painter: _PinTailPainter(color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserHalo(Offset point) {
    const double size = 64;
    return Positioned(
      left: point.dx - size / 2,
      top: point.dy - size / 2,
      width: size,
      height: size,
      child: IgnorePointer(
        child: Transform.scale(
          scale: 1 / _scale,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final t = _pulse.value;
              return Center(
                child: Container(
                  width: size * (0.35 + 0.65 * t),
                  height: size * (0.35 + 0.65 * t),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.style.userMarker.withOpacity(0.22 * (1 - t)),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // --- оформление ---------------------------------------------------------

  Widget _buildZoomControls(Size canvas) {
    Widget button(IconData icon, String tooltip, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Material(
            elevation: 3,
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            child: Tooltip(
              message: tooltip,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: onTap,
                child: SizedBox(
                    width: 40, height: 40, child: Icon(icon, size: 20)),
              ),
            ),
          ),
        );
    return Column(
      children: [
        button(Icons.add, 'Приблизить', () => _zoomBy(1.4, canvas)),
        button(Icons.remove, 'Отдалить', () => _zoomBy(1 / 1.4, canvas)),
        button(Icons.center_focus_strong, 'Весь план', _resetZoom),
      ],
    );
  }

  Widget _buildHint(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: const TextStyle(color: Colors.white, fontSize: 11)),
      );

  Widget _buildImageError() => Container(
        color: widget.style.surface,
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.map_outlined, size: 32, color: Color(0xFF8A8F98)),
              const SizedBox(height: 8),
              const Text('План этажа не загрузился',
                  style: TextStyle(fontSize: 13, color: Color(0xFF5A606B))),
              TextButton(
                onPressed: () {
                  setState(() => _imageError = null);
                  _lastFrameKey = null;
                  _resolveImageSize();
                },
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
}

// ===========================================================================
// Отрисовка зон и маршрута
// ===========================================================================

/// Статический слой: зоны и подписи. Намеренно БЕЗ animation и без
/// super(repaint:) — иначе весь слой (включая 90 подписей) перерисовывался
/// бы на каждый тик пульса, минуя shouldRepaint. Маршрут живёт отдельно,
/// в [_RoutePainter].
class _MapPainter extends CustomPainter {
  final List<MallStore> stores;
  final String? selectedId;
  final Set<String> visitedIds;
  final Set<String> highlightedIds;
  final MallMapStyle style;
  final double scale;

  _MapPainter({
    required this.stores,
    required this.selectedId,
    required this.visitedIds,
    required this.highlightedIds,
    required this.style,
    required this.scale,
  });

  /// Ширина слова в кеглях (em), ЗАМЕРЕННАЯ, а не оценённая по числу
  /// символов: у «M», «W», «Ш» глиф доходит до 0.9em, из-за чего слово не
  /// влезало в отведённую ширину и Flutter рвал его посередине
  /// («Massim / o Dutti»). Ключ — само слово, так что записей максимум
  /// столько, сколько уникальных названий в ТЦ.
  static final Map<String, double> _wordWidthEmCache = {};

  /// Замер делаем на эталонном кегле 100 и на w600 — самом широком весе,
  /// который мы используем. Поэтому оценка консервативная и не зависит от
  /// итогового кегля: иначе получилась бы рекурсия «вес зависит от
  /// размера, размер — от замера».
  static double _wordWidthEm(String word) {
    if (word.isEmpty) return 0;
    final cached = _wordWidthEmCache[word];
    if (cached != null) return cached;

    const probeSize = 100.0;
    // Фолбэк на старую оценку 0.55em на символ, если замер не удался.
    var em = word.length * 0.55;
    try {
      final probe = TextPainter(
        text: TextSpan(
          text: word,
          style: const TextStyle(
            fontSize: probeSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final measured = probe.width / probeSize;
      probe.dispose();
      if (measured.isFinite && measured > 0) em = measured;
    } catch (_) {
      // остаёмся на оценке
    }

    _wordWidthEmCache[word] = em;
    return em;
  }

  double _px(double screenPx) => screenPx / scale;

  @override
  void paint(Canvas canvas, Size size) {
    final ordered = [...stores]
      ..sort((a, b) => b.zone.area.compareTo(a.zone.area));

    for (final store in ordered) {
      final selected = store.id == selectedId;
      final visited = visitedIds.contains(store.id);
      final highlighted = highlightedIds.contains(store.id);

      final fill = selected
          ? style.zoneSelected
          : highlighted
              ? style.zoneHighlighted
              : visited
                  ? style.zoneVisited
                  : style.zoneIdle;

      final path = store.zone.toPath(size);
      canvas.drawPath(path, Paint()..color = fill);

      if (selected || highlighted) {
        canvas.drawPath(
          path,
          Paint()
            ..color = highlighted ? style.highlightBorder : style.zoneBorder
            ..style = PaintingStyle.stroke
            ..strokeWidth = _px(highlighted ? 2.5 : 2),
        );
      }

      _paintLabel(canvas, size, store.zone, store.name);
    }
  }

  // --- подписи ------------------------------------------------------------

  /// Область, в которую встаёт подпись: габариты произвольного контура из
  /// label_polygon, иначе прямоугольник label_rect, иначе дефолт от
  /// габаритов зоны.
  Rect? _effectiveLabelRect(ShopZone zone) {
    final poly = zone.labelPolygon;
    if (poly != null && poly.length >= 3) {
      var minX = poly.first.dx, maxX = poly.first.dx;
      var minY = poly.first.dy, maxY = poly.first.dy;
      for (final p in poly) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }
      return Rect.fromLTRB(minX, minY, maxX, maxY);
    }
    if (zone.labelRect != null) return zone.labelRect;
    // Дефолт: 80% ширины × 55% высоты зоны, по её центру. Гарантирует, что
    // любой магазин получит подпись, даже если оператор её не настраивал.
    final b = zone.bounds;
    if (b.width <= 0 || b.height <= 0) return null;
    final w = b.width * 0.8;
    final h = b.height * 0.55;
    return Rect.fromCenter(center: b.center, width: w, height: h);
  }

  /// TextPainter подписи для заданного кегля и длины строки.
  ///
  /// Вес зависит от ВИДИМОГО размера (кегль × зум): мелкому тексту вес
  /// нужен для читаемости, а крупный w600 выглядел бы тяжелее линий плана.
  TextPainter _buildLabelPainter(
      String name, double fontSize, double maxWidth) {
    final visible = fontSize * scale;
    final weight = visible >= 18
        ? FontWeight.w400
        : visible >= 13
            ? FontWeight.w500
            : FontWeight.w600;
    return TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: weight,
          color: const Color(0xFF14171C),
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
  }

  void _paintLabel(Canvas canvas, Size size, ShopZone zone, String name) {
    final labelRect = _effectiveLabelRect(zone);
    if (labelRect != null && labelRect.width > 0 && labelRect.height > 0) {
      // Область подписи: нарисованная оператором или дефолтная от габаритов
      // зоны. Проверок контура и anchor-room здесь нет — место уже выбрано,
      // остаётся подобрать кегль и ориентацию.
      final rectPx = Rect.fromLTWH(
        labelRect.left * size.width,
        labelRect.top * size.height,
        labelRect.width * size.width,
        labelRect.height * size.height,
      );
      // Константы отступа и кегля ниже (8/9/16/24/32/5/3) подбирались на
      // холсте iPhone шириной ~377px. Приводим их к фактической ширине
      // холста: иначе один и тот же магазин переносится по-разному на
      // телефоне, планшете и в предпросмотре админки, где холст втрое шире.
      final canvasRatio = size.width / 377.0;

      // Отступ внутри области: 8 приведённых пикселей, но не больше 8%
      // ширины. На крупной области — как раньше, на мелкой он больше не
      // съедает её целиком. Раньше у зоны 40×30 px дефолтная область 24×12
      // после вычета 8+8 оставляла 4 px высоты, строка туда не влезала ни
      // на каком кегле — и подпись не рисовалась вообще.
      final pad = math.min(8 * canvasRatio / scale, rectPx.width * 0.08);
      // Меньше пикселя — не повод отказываться от подписи: что реально
      // влезет, решают циклы подбора кегля ниже.
      final innerW = math.max(1.0, rectPx.width - pad);
      final innerH = math.max(1.0, rectPx.height - pad);

      // Узкая высокая область -> текст идёт вдоль неё, повёрнутый на 90°.
      // Нарисованному вручную контуру ориентацию не навязываем: оператор
      // уже задал её формой.
      // Автоматическая вертикаль применяется только если оператор не задал
      // угол. Явный угол — воля оператора, он сильнее эвристики формы.
      final hasAngle = (zone.labelAngle ?? 0) != 0;
      final vertical = !hasAngle &&
          zone.labelPolygon == null &&
          rectPx.height > rectPx.width * 1.3;

      // Длина строки идёт по одной оси области, толщина блока — по другой.
      // Для повёрнутой подписи они меняются местами.
      final runPx = vertical ? innerH : innerW;
      final thinPx = vertical ? innerW : innerH;

      // Дефолтная область (оператор ничего не задавал) бывает совсем
      // мелкой — ей разрешаем опускаться до 3px, лишь бы подпись была.
      // Заданным руками области и полигону оставляем прежние 5px.
      final isDefaultRect =
          zone.labelPolygon == null && zone.labelRect == null;

      // Потолок кегля зависит от зума: на общем виде подписи мелкие (не
      // превращаются в кашу), на глубоком зуме крупные (читаются).
      // scale 1 -> 9px, scale 2 -> 12px, scale 6 и дальше -> 24px.
      final zoomCap = math.min(24.0, math.max(9.0, 9.0 + (scale - 1.0) * 3.0)) *
          canvasRatio /
          scale;
      final maxFont = math.min(zoomCap, 32.0 * canvasRatio / scale);
      final minFont = (isDefaultRect ? 3.0 : 5.0) * canvasRatio / scale;
      // Старт — 16px, но не выше потолка: иначе крупная зона на общем виде
      // игнорировала бы zoomCap и давала кашу из подписей.
      var fontSize = math.min(16.0 * canvasRatio / scale, maxFont);

      // Растём, пока влезает: если после старта в области остаётся место,
      // текст должен им пользоваться. didExceedMaxLines страхует от роста
      // в многоточие — влезшей считается только целая подпись.
      while (true) {
        final next = fontSize / 0.9;
        if (next > maxFont) break;
        final probe = _buildLabelPainter(name, next, runPx);
        final fits = probe.height <= thinPx && !probe.didExceedMaxLines;
        probe.dispose();
        if (!fits) break;
        fontSize = next;
      }

      // Затем обычная усадка, если стартовый кегль не влез.
      var painter = _buildLabelPainter(name, fontSize, runPx);
      while (painter.height > thinPx && fontSize > minFont) {
        painter.dispose();
        fontSize *= 0.9;
        painter = _buildLabelPainter(name, fontSize, runPx);
      }
      // Намеренно НЕ проверяем painter.height повторно: если текст не влез
      // даже на минимальном кегле, рисуем как есть. Смысл дефолтной области
      // в том, чтобы подпись была у каждого магазина, а зона без названия
      // хуже мелкого названия.

      final center = rectPx.center;
      final rad = (zone.labelAngle ?? 0) * math.pi / 180;
      final topLeft = Offset(-painter.width / 2, -painter.height / 2);

      if (vertical) {
        // Форма сама диктует ориентацию, поэтому label_angle здесь не
        // применяем. Две строки многословного названия так и останутся
        // двумя строками — повернётся весь блок целиком.
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(math.pi / 2);
        painter.paint(canvas, topLeft);
        canvas.restore();
      } else if (rad != 0) {
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(rad);
        painter.paint(canvas, topLeft);
        canvas.restore();
      } else {
        painter.paint(canvas, center + topLeft);
      }
      painter.dispose();
      return;
    }

    // Ручной угол подписи из админки (shops.label_angle), в радианах.
    // Применяется ОДНИМ поворотом холста в самом конце, вокруг якоря:
    // все замеры ниже (кегль, усадка, проверка углов) считаются в
    // неповёрнутых координатах и остаются такими же, как были.
    final labelTurn = (zone.labelAngle ?? 0) * math.pi / 180;

    final b = zone.bounds;
    final zoneWidthPx = b.width * size.width * scale;
    final zoneHeightPx = b.height * size.height * scale;

    // Многословные названия переносим на две строки, поэтому кегль считаем
    // по САМОМУ ДЛИННОМУ СЛОВУ: именно оно задаёт ширину широкой строки.
    // Для «Coffee Bean» это «Coffee», а не все 11 символов. Ширину слова
    // замеряем (см. _wordWidthEm), а не оцениваем по числу символов.
    final multiWord = name.trim().contains(RegExp(r'\s'));
    final longestWord = name.trim().split(RegExp(r'\s+')).fold<String>(
          '',
          (longest, w) => w.length > longest.length ? w : longest,
        );
    final nameSpan = math.max(_wordWidthEm(longestWord), 3);
    final maxFontByWidth = zoneWidthPx / nameSpan;
    final maxFontByHeight = zoneHeightPx / nameSpan;

    // Поворот — только для названий из одного слова. Две повёрнутые строки
    // дали бы два столбца вбок, это нечитаемо: многословные всегда верстаем
    // горизонтально, строками друг под другом.
    final bool vertical;
    if (multiWord) {
      vertical = false;
    } else if (zoneHeightPx > zoneWidthPx * 1.1) {
      vertical = true;
    } else {
      vertical = maxFontByWidth < 6.0 && maxFontByHeight >= 6.0;
    }

    // Подпись центрируется на labelAnchor, а у невыпуклых зон (L, U) он НЕ
    // совпадает с центром bounds. Поэтому мерим место по обе стороны от
    // якоря: иначе подпись во всю ширину зоны, но с центром в стороне,
    // вылезает на соседний магазин. Для прямоугольника это ровно bounds.
    final ax = zone.labelAnchor.dx, ay = zone.labelAnchor.dy;
    final roomX = 2 * math.min(ax - b.left, b.right - ax) * size.width * scale;
    final roomY = 2 * math.min(ay - b.top, b.bottom - ay) * size.height * scale;

    // Дальше всё считаем от длины той оси, по которой пойдёт текст.
    final runPx = vertical ? roomY : roomX;
    final thinPx = vertical ? roomX : roomY;

    // --- Кегль -------------------------------------------------------------
    //
    // ЕДИНИЦЫ. zoneWidthPx/zoneHeightPx уже умножены на scale — это пиксели
    // ЭКРАНА, а не холста. Значит и fontSize здесь экранный: при отрисовке
    // он делится на scale (fontSize / scale), а трансформация зума умножает
    // обратно, поэтому ВИДИМЫЙ кегль равен ровно fontSize. Константы ниже
    // (9, 24, 6) — тоже экранные пиксели. Смешать единицы нельзя: если
    // считать кегль от холста, он перестанет расти при зуме.
    //
    // Берём минимум из трёх ограничений:
    //   1. влезть в зону по ОБЕИМ осям: по длине — самым длинным словом,
    //      по толщине — блоком из lines строк (строка ≈ 1.17 кегля);
    //   2. потолок от зума: на общем виде мелко, чтобы не было каши,
    //      на глубоком зуме крупно, чтобы читалось с телефона;
    //   3. потолок от самой зоны, чтобы подпись её не переросла — ни в
    //      длину, ни в толщину (0.8 от толщины: высота строки ≈ 1.17 кегля).
    //
    // lines = 1 для одного слова: место под вторую строку резервировать
    // нельзя, иначе кегль одиночных названий падает вдвое. Одно слово на
    // две строки и не переносится — кегль подобран так, что оно влезает.
    final lines = multiWord ? 2 : 1;
    final fitFont = math.min(
      (runPx - 6) / nameSpan,
      (thinPx - 6) / (lines * 1.17),
    );
    final zoomCap = math.min(24.0, math.max(9.0, 9.0 + (scale - 1.0) * 3.0));
    final zoneCap = math.min(runPx * 0.35, thinPx * 0.8);
    final fontSize =
        math.max(5.0, math.min(fitFont, math.min(zoomCap, zoneCap)));

    final labelMaxWidth = runPx / scale - _px(6);

    // Места под текст не осталось совсем (якорь вплотную к краю зоны) —
    // выходим ДО обеих ветвей видимости: layout с отрицательной шириной
    // падает в debug.
    if (labelMaxWidth <= 0) return;

    // Видимость подписи зависит от зума: чем ближе, тем больше названий.
    if (scale >= 2.0) {
      // Приблизили — порог по размеру зоны снимаем, подписи нужны и у
      // маленьких магазинов. Остаются два ограничения: читаемость шрифта
      // и наличие места под текст (при отрицательной ширине падает layout).
      if (fontSize < 5.0 || labelMaxWidth <= 0) return;
    } else if (zoneWidthPx < 24 || zoneHeightPx < 10) {
      // Общий вид — подписываем только крупные зоны, иначе каша.
      return;
    }

    // Симметричная проверка: подпись должна лежать внутри САМОГО контура, а
    // не внутри его bounding box — у невыпуклых зон это разные вещи, и угол
    // подписи оказывается на соседнем магазине. Проверка строже прежнего
    // отсева по высоте (без 20% допуска) и ловит обе оси сразу.
    //
    // Берём ширину САМОЙ ШИРОКОЙ СТРОКИ, а не p.width: у подписи,
    // перенесённой на две строки, p.width равен всей выделенной ширине, и
    // проверка браковала бы любую двухстрочную подпись в непрямоугольной
    // зоне — то есть ровно те подписи, которые мы лечим.
    bool cornersInside(TextPainter p) {
      final widestLine = p
          .computeLineMetrics()
          .fold<double>(0, (m, l) => l.width > m ? l.width : m);
      final drawnRun = widestLine > 0 ? widestLine : p.width;
      // В повёрнутом режиме длина текста идёт по вертикали, а толщина — по
      // горизонтали, поэтому каждую сторону нормируем на свою сторону
      // холста.
      final halfX = (vertical ? p.height : drawnRun) / 2 / size.width;
      final halfY = (vertical ? drawnRun : p.height) / 2 / size.height;
      return zone.contains(Offset(ax - halfX, ay - halfY)) &&
          zone.contains(Offset(ax + halfX, ay - halfY)) &&
          zone.contains(Offset(ax + halfX, ay + halfY)) &&
          zone.contains(Offset(ax - halfX, ay + halfY));
    }

    TextPainter buildPainter(double fs) {
      // Чем крупнее подпись, тем легче начертание: w600 на 24px выглядит
      // тяжелее линий плана, а мелкому тексту вес наоборот нужен. Вес
      // считаем от ТЕКУЩЕГО кегля: после усадки подпись снова мелкая и
      // ей снова нужен вес.
      final weight = fs >= 18
          ? FontWeight.w400
          : fs >= 13
              ? FontWeight.w500
              : FontWeight.w600;
      return TextPainter(
        text: TextSpan(
          text: name,
          style: TextStyle(
            fontSize: fs / scale,
            fontWeight: weight,
            color: const Color(0xFF14171C),
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: labelMaxWidth);
    }

    // Не влезло в контур — не прячем сразу, а уменьшаем кегль: зона совсем
    // без названия хуже мелкого названия. Три попытки по 20% дают 51% от
    // исходного кегля; ниже 5px не опускаемся — там уже нечитаемо, и тогда
    // подпись действительно не рисуем.
    var currentFont = fontSize;
    var painter = buildPainter(currentFont);
    var fits = cornersInside(painter);
    var attempts = 0;
    while (!fits && attempts < 3) {
      final next = currentFont * 0.8;
      if (next < 5.0) break;
      painter.dispose();
      currentFont = next;
      painter = buildPainter(currentFont);
      fits = cornersInside(painter);
      attempts++;
    }
    if (!fits) {
      painter.dispose();
      return;
    }

    final anchor = Offset(
      zone.labelAnchor.dx * size.width,
      zone.labelAnchor.dy * size.height,
    );

    // Только текст, без плашки. Центруем его по якорю зоны.
    final textTopLeft = Offset(-painter.width / 2, -painter.height / 2);

    // Заданный руками угол ЗАМЕНЯЕТ автоповорот: оператор сказал «45°» —
    // значит 45°, а не 45° поверх вертикальной подписи. Угол не задан или
    // равен нулю -> turn тот же, что был до появления label_angle.
    final turn = labelTurn != 0 ? labelTurn : (vertical ? math.pi / 2 : 0.0);

    if (turn != 0) {
      // Разворачиваем систему координат вокруг якоря — дальше рисуем ровно
      // так же, как в горизонтальном случае, но уже от локального нуля.
      canvas.save();
      canvas.translate(anchor.dx, anchor.dy);
      canvas.rotate(turn);
      painter.paint(canvas, textTopLeft);
      canvas.restore();
      return;
    }

    painter.paint(canvas, anchor + textTopLeft);
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) =>
      old.stores != stores ||
      old.selectedId != selectedId ||
      old.visitedIds != visitedIds ||
      old.highlightedIds != highlightedIds ||
      old.scale != scale;
}

/// Динамический слой: только пунктирный маршрут. Он единственный, кому
/// нужен пульс, поэтому super(repaint:) остаётся здесь — перерисовка
/// кадр в кадр стоит одну ломаную, а не 90 TextPainter'ов.
class _RoutePainter extends CustomPainter {
  final List<Offset>? route;
  final double scale;
  final Color routeColor;
  final Animation<double> animation;

  _RoutePainter({
    required this.route,
    required this.scale,
    required this.routeColor,
    required this.animation,
  }) : super(repaint: animation);

  /// Тот же пересчёт экранных пикселей в холстовые, что и у _MapPainter.
  double _px(double screenPx) => screenPx / scale;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = route;
    if (pts == null || pts.length < 2) return;

    final t = animation.value;
    final dash = _px(12);
    final gap = _px(9);
    final phase = t * (dash + gap);
    final opacity = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(t * 2 * math.pi));

    final dashed = _dash(_routePath(pts), dash: dash, gap: gap, phase: phase);

    canvas.drawPath(
      dashed,
      Paint()
        ..color = Colors.white.withOpacity(0.55 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _px(9)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      dashed,
      Paint()
        ..color = routeColor.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _px(5)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
        pts.first, _px(5), Paint()..color = routeColor.withOpacity(opacity));
  }

  Path _routePath(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    final radius = _px(18);
    for (var i = 1; i < pts.length; i++) {
      if (i == pts.length - 1) {
        path.lineTo(pts[i].dx, pts[i].dy);
        continue;
      }
      final prev = pts[i - 1], current = pts[i], next = pts[i + 1];
      final inLength = (current - prev).distance;
      final outLength = (next - current).distance;
      if (inLength < 0.01 || outLength < 0.01) {
        path.lineTo(current.dx, current.dy);
        continue;
      }
      final r = math.min(radius, math.min(inLength, outLength) / 2);
      final entry = current + (prev - current) / inLength * r;
      final exit = current + (next - current) / outLength * r;
      path.lineTo(entry.dx, entry.dy);
      path.quadraticBezierTo(current.dx, current.dy, exit.dx, exit.dy);
    }
    return path;
  }

  Path _dash(Path source,
      {required double dash, required double gap, required double phase}) {
    final result = Path();
    final period = dash + gap;
    for (final metric in source.computeMetrics()) {
      var distance = -(phase % period);
      while (distance < metric.length) {
        final start = math.max(distance, 0.0);
        final end = math.min(distance + dash, metric.length);
        if (end > start) {
          result.addPath(metric.extractPath(start, end), Offset.zero);
        }
        distance += period;
      }
    }
    return result;
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) =>
      old.route != route || old.scale != scale;
}

class _PinTailPainter extends CustomPainter {
  final Color color;
  const _PinTailPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawShadow(path, Colors.black.withOpacity(0.3), 2, false);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PinTailPainter old) => old.color != color;
}