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
    // Сменилась цель маршрута или точка старта — пересчитать кадр превью.
    // Список магазинов пересобирается на каждый build родителя, поэтому в
    // условие он не входит: смена состава зон меняет размер холста, а это
    // уже ловится в build.
    if (old.selectedStoreId != widget.selectedStoreId ||
        old.entrancePosition != widget.entrancePosition ||
        old.userPosition != widget.userPosition ||
        old.planBounds != widget.planBounds) {
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

  /// Кадрирует превью.
  ///
  /// Магазин не выбран — центрируемся на входе в ТЦ с фиксированным зумом
  /// [_entranceZoom]: превью отвечает «откуда я начинаю и что рядом».
  /// Магазин выбран — показываем маршрут: кадр вокруг входа и двери
  /// магазина с запасом, зум подбираем так, чтобы влезли оба маркера.
  void _applyAutoFrame(Size canvas) {
    if (!widget.autoFrame || canvas.isEmpty) return;

    final entrance = widget.userPosition ?? widget.entrancePosition;
    final selected = _selectedStore;

    final key = '${widget.mapImageUrl}|${selected?.id ?? "none"}'
        '|${canvas.width.round()}x${canvas.height.round()}'
        '|${entrance.dx.toStringAsFixed(3)},${entrance.dy.toStringAsFixed(3)}';
    if (key == _lastFrameKey) return;
    _lastFrameKey = key;

    final double scale;
    final Offset target;
    if (selected == null) {
      scale = _entranceZoom.clamp(widget.minScale, widget.maxScale);
      target = _toCanvas(entrance, canvas);
    } else {
      final box = Rect.fromPoints(
        _toCanvas(entrance, canvas),
        _toCanvas(selected.zone.destination, canvas),
      );
      final pad = math.max(40.0, math.max(box.width, box.height) * 0.25);
      // Сверху запас больше: булавка маркера рисуется НАД точкой.
      final frame = Rect.fromLTRB(
        box.left - pad,
        box.top - pad - _markerHeight,
        box.right + pad,
        box.bottom + pad,
      ).intersect(Offset.zero & canvas);

      // Кадр обрезан по холсту, поэтому масштаб «чтобы влез целиком»
      // всегда >= 1: оба маркера гарантированно в кадре.
      scale = math
          .min(canvas.width / math.max(frame.width, 1.0),
              canvas.height / math.max(frame.height, 1.0))
          .clamp(widget.minScale, math.min(3.0, widget.maxScale));
      target = frame.center;
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
        final width = math.min(
          constraints.maxWidth.isFinite ? constraints.maxWidth : widget.maxWidth,
          widget.maxWidth,
        );
        // Холст совпадает с карточкой: height, если задана, иначе высота
        // по пропорциям плана. Кадрированием занимается _applyAutoFrame.
        final canvas = Size(width, widget.height ?? width / _aspectRatio);

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

    // В превью кадрирование делает _applyAutoFrame; в интерактиве
    // пользователь сам рулит — матрицу не трогаем.
    final panEnabled = widget.interactive && _scale > 1.01;
    final scaleEnabled = widget.interactive &&
        (!kIsWeb || _wheelZoomArmed || _scale > 1.01);

    return InteractiveViewer(
      transformationController: _controller,
      minScale: widget.minScale,
      maxScale: widget.maxScale,
      panEnabled: panEnabled,
      scaleEnabled: scaleEnabled,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
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

            // 2 + 3. Зоны и маршрут
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
                    route: (widget.showRoute && selected != null)
                        ? _routeWaypoints(
                            userPoint,
                            _toCanvas(selected.zone.destination, canvas),
                          )
                        : null,
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
      ),
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

class _MapPainter extends CustomPainter {
  final List<MallStore> stores;
  final String? selectedId;
  final Set<String> visitedIds;
  final Set<String> highlightedIds;
  final MallMapStyle style;
  final double scale;
  final List<Offset>? route;
  final Animation<double> animation;

  _MapPainter({
    required this.stores,
    required this.selectedId,
    required this.visitedIds,
    required this.highlightedIds,
    required this.style,
    required this.scale,
    required this.route,
    required this.animation,
  }) : super(repaint: animation);

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

    if (route != null && route!.length >= 2) _paintRoute(canvas);
  }

  // --- подписи ------------------------------------------------------------

  void _paintLabel(Canvas canvas, Size size, ShopZone zone, String name) {
    final b = zone.bounds;
    final zoneWidthPx = b.width * size.width * scale;
    final zoneHeightPx = b.height * size.height * scale;

    if (zoneWidthPx < 24 || zoneHeightPx < 10) return;

    final maxFontByWidth = zoneWidthPx / math.max(name.length * 0.55, 3);
    final fontSize = math.min(11.0, math.max(6.0, maxFontByWidth));

    final painter = TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(
          fontSize: fontSize / scale,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF14171C),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: zoneWidthPx / scale - _px(6));

    final anchor = Offset(
      zone.labelAnchor.dx * size.width,
      zone.labelAnchor.dy * size.height,
    );

    final bg = Rect.fromCenter(
      center: anchor,
      width: painter.width + _px(6),
      height: painter.height + _px(4),
    );

    if (fontSize >= 8) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(bg, Radius.circular(_px(3))),
        Paint()..color = Colors.white.withOpacity(0.85),
      );
    }

    painter.paint(canvas, bg.topLeft + Offset(_px(3), _px(2)));
  }

  // --- маршрут ------------------------------------------------------------

  void _paintRoute(Canvas canvas) {
    final t = animation.value;
    final dash = _px(12);
    final gap = _px(9);
    final phase = t * (dash + gap);
    final opacity = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(t * 2 * math.pi));

    final dashed = _dash(_routePath(), dash: dash, gap: gap, phase: phase);

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
        ..color = style.route.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _px(5)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(route!.first, _px(5),
        Paint()..color = style.route.withOpacity(opacity));
  }

  Path _routePath() {
    final pts = route!;
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
  bool shouldRepaint(covariant _MapPainter old) =>
      old.stores != stores ||
      old.selectedId != selectedId ||
      old.visitedIds != visitedIds ||
      old.highlightedIds != highlightedIds ||
      old.scale != scale ||
      old.route != route;
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