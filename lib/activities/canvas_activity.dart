import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/controller.dart';
import '../core/models.dart';
import '../ui/vector_art.dart';
import '../ui/brush_stroke.dart';

class CanvasActivity extends StatefulWidget {
  final Activity activity;
  final AppController app;
  final VoidCallback onComplete;
  final ValueChanged<bool>? onFullScreenChanged;
  const CanvasActivity({
    super.key,
    required this.activity,
    required this.app,
    required this.onComplete,
    this.onFullScreenChanged,
  });
  @override
  State<CanvasActivity> createState() => CanvasActivityState();
}

class CanvasActivityState extends State<CanvasActivity>
    with WidgetsBindingObserver {
  Map<String, dynamic> drawing = {
    'artRevision': 3,
    'fills': <String, dynamic>{},
    'strokes': <dynamic>[],
  };
  final List<String> undo = [], redo = [];
  final TransformationController transform = TransformationController();
  String tool = 'fill';
  BrushStyle brush = BrushStyle.round;
  int selected = 0;
  double width = 12;
  int guide = 1;
  bool loaded = false, dirty = false, strokeActive = false;
  bool fullScreen = false;
  bool _resetDialogOpen = false;
  Size? _viewportSize;
  double get zoom => transform.value.storage[0];
  Timer? saveTimer;
  Future<void> pending = Future.value();
  static const colors = [
    0xFFF17C6E,
    0xFFF3C65F,
    0xFF8DB77B,
    0xFF74BEC6,
    0xFF9B8ACA,
    0xFFE992AB,
    0xFFF9D5B8,
    0xFF7C5846,
    0xFF344850,
    0xFFFFFFFF,
    0xFFE6AF5D,
    0xFF546FAD,
    0xFFC73845,
    0xFFE9553D,
    0xFFEB892B,
    0xFFFFB43B,
    0xFFF7E46F,
    0xFFA9CF55,
    0xFF4F944A,
    0xFF256B4E,
    0xFF38A78B,
    0xFF247D8A,
    0xFF4D9DE0,
    0xFF284A83,
    0xFF6945A0,
    0xFFB46EC0,
    0xFFC84080,
    0xFFF5BFD7,
    0xFFB87D56,
    0xFF51382E,
    0xFFF2CFAD,
    0xFFD7A487,
    0xFF97634F,
    0xFFB5B9C3,
    0xFF737985,
    0xFF20242E,
  ];
  static Color swatchForeground(int color) {
    const ink = Color(0xFF344850);
    final background = Color(color).computeLuminance() + 0.05;
    return 1.05 / background > background / (ink.computeLuminance() + 0.05)
        ? Colors.white
        : ink;
  }

  Map<String, dynamic> get config =>
      widget.activity.config(widget.app.language);
  VectorScene? get scene => sceneFor(
    widget.app.catalog.artForRevision(drawing['artRevision'] ?? 2),
    config['scene'],
  );
  bool get isDrawing => config['mode'] == 'drawing';
  int get initialGuide {
    final step = isDrawing ? [1, 3, 6, 999][config['guide'] ?? 0] : 1;
    return scene == null ? step : step.clamp(1, scene!.guideSteps);
  }

  bool get canReset =>
      (drawing['strokes'] as List).isNotEmpty ||
      (drawing['fills'] as Map).isNotEmpty ||
      guide != initialGuide;

  Future<void> _confirmReset() async {
    if (_resetDialogOpen || !canReset) return;
    _resetDialogOpen = true;
    final app = widget.app;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(app.t('resetDrawingTitle')),
        content: Text(app.t('resetDrawingHelp')),
        actions: [
          TextButton(
            key: const ValueKey('canvas-reset-cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(app.t('cancel')),
          ),
          FilledButton(
            key: const ValueKey('canvas-reset-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(app.t('resetDrawing')),
          ),
        ],
      ),
    );
    _resetDialogOpen = false;
    if (!mounted || confirmed != true) return;
    setState(() {
      _snapshot();
      strokeActive = false;
      pinching = false;
      guide = initialGuide;
      drawing = {
        'artRevision': drawing['artRevision'],
        'guide': guide,
        'fills': <String, dynamic>{},
        'strokes': <dynamic>[],
      };
    });
    _changed();
    await save();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (isDrawing) {
      tool = 'brush';
      guide = [1, 3, 6, 999][config['guide'] ?? 0];
    }
    _load();
  }

  Future<void> _load() async {
    final saved = await widget.app.artwork(widget.activity.id);
    if (!mounted) return;
    setState(() {
      if (saved != null) {
        drawing = saved;
        drawing.putIfAbsent('artRevision', () => 2);
        guide = drawing['guide'] ?? guide;
      }
      if (scene != null) guide = guide.clamp(1, scene!.guideSteps);
      drawing['guide'] = guide;
      loaded = true;
    });
  }

  void _snapshot() {
    drawing['guide'] = guide;
    undo.add(jsonEncode(drawing));
    if (undo.length > 60) undo.removeAt(0);
    redo.clear();
  }

  void _changed() {
    dirty = true;
    drawing['guide'] = guide;
    saveTimer?.cancel();
    saveTimer = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(save()),
    );
  }

  void _restore(String snapshot) {
    drawing = Map<String, dynamic>.from(jsonDecode(snapshot));
    guide = drawing['guide'] ?? 1;
    if (scene != null) guide = guide.clamp(1, scene!.guideSteps);
  }

  Future<void> save() {
    saveTimer?.cancel();
    if (!loaded || !dirty) return Future.value();
    pending = widget.app.saveArtwork(
      widget.activity.id,
      drawing,
      scene: config['scene'],
    );
    return pending;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(save());
  }

  bool pinching = false, dirtyBeforeGesture = false;
  List<String> redoBeforeGesture = [];
  List<String> undoBeforeGesture = [];
  Offset pinchAnchor = Offset.zero;
  double pinchScale = 1, gestureScale = 1;
  Offset _boardOffset(Size size) {
    final side = math.min(size.width, size.height);
    return Offset((size.width - side) / 2, (size.height - side) / 2);
  }

  Matrix4 _viewportMatrix(
    double factor,
    Offset focal,
    Offset anchor,
    Size size,
  ) {
    final side = math.min(size.width, size.height);
    final offset = _boardOffset(size);
    double bound(double translation, double viewport, double origin) {
      if (side * factor <= viewport) {
        return (viewport - side * factor) / 2 - origin * factor;
      }
      return translation.clamp(
        viewport - (origin + side) * factor,
        -origin * factor,
      );
    }

    return Matrix4.identity()
      ..translateByDouble(
        bound(focal.dx - anchor.dx * factor, size.width, offset.dx),
        bound(focal.dy - anchor.dy * factor, size.height, offset.dy),
        0,
        1,
      )
      ..scaleByDouble(factor, factor, 1, 1);
  }

  void _resizeViewport(Size size) {
    final old = _viewportSize;
    if (old != null && old != size && !old.isEmpty && !size.isEmpty) {
      final fraction =
          (transform.toScene(old.center(Offset.zero)) - _boardOffset(old)) /
          math.min(old.width, old.height);
      final anchor =
          _boardOffset(size) + fraction * math.min(size.width, size.height);
      transform.value = _viewportMatrix(
        zoom,
        size.center(Offset.zero),
        anchor,
        size,
      );
    }
    _viewportSize = size;
  }

  void zoomBy(double amount) {
    final size = _viewportSize;
    if (size == null) return;
    final center = size.center(Offset.zero);
    setState(
      () => transform.value = _viewportMatrix(
        (zoom + amount).clamp(1.0, 4.0),
        center,
        transform.toScene(center),
        size,
      ),
    );
  }

  void setFullScreen(bool value) {
    if (fullScreen == value) return;
    strokeActive = false;
    pinching = false;
    unawaited(save());
    setState(() => fullScreen = value);
    widget.onFullScreenChanged?.call(value);
  }

  void scaleStart(ScaleStartDetails details, Size size) {
    pinching = false;
    dirtyBeforeGesture = dirty;
    redoBeforeGesture = List.of(redo);
    undoBeforeGesture = List.of(undo);
    if (details.pointerCount == 1 && tool != 'fill') {
      start(transform.toScene(details.localFocalPoint), size);
    }
  }

  void scaleUpdate(ScaleUpdateDetails details, Size size) {
    if (details.pointerCount > 1) {
      if (!pinching) {
        if (strokeActive && undo.isNotEmpty) {
          _restore(undo.removeLast());
          dirty = dirtyBeforeGesture;
          undo
            ..clear()
            ..addAll(undoBeforeGesture);
          redo
            ..clear()
            ..addAll(redoBeforeGesture);
        }
        strokeActive = false;
        pinching = true;
        pinchScale = transform.value.storage[0];
        gestureScale = details.scale;
        pinchAnchor = transform.toScene(details.localFocalPoint);
      }
      final factor = (pinchScale * details.scale / gestureScale).clamp(
        1.0,
        4.0,
      );
      setState(
        () => transform.value = _viewportMatrix(
          factor,
          details.localFocalPoint,
          pinchAnchor,
          size,
        ),
      );
    } else if (!pinching && tool != 'fill') {
      move(transform.toScene(details.localFocalPoint), size);
    }
  }

  void start(Offset position, Size size) {
    strokeActive = false;
    if (!loaded) return;
    final logical = scene?.size ?? const Size(600, 600);
    final local = position - _boardOffset(size);
    final side = math.min(size.width, size.height);
    final p = Offset(
      local.dx / side * logical.width,
      local.dy / side * logical.height,
    );
    if (p.dx < 0 || p.dy < 0 || p.dx > logical.width || p.dy > logical.height) {
      return;
    }
    _snapshot();
    if (tool == 'fill') {
      final region = scene?.regionAt(p);
      if (region == null) {
        undo.removeLast();
        return;
      }
      setState(() {
        drawing['fills'][region] = colors[selected];
      });
      _changed();
    } else {
      final region = isDrawing ? null : scene?.regionAt(p);
      if (!isDrawing && region == null) {
        undo.removeLast();
        return;
      }
      strokeActive = true;
      setState(() {
        (drawing['strokes'] as List).add({
          'color': tool == 'erase' ? 0xFFFFFFFF : colors[selected],
          'width': width,
          'brush': tool == 'erase' ? BrushStyle.round.name : brush.name,
          'region': region,
          'points': [
            [p.dx, p.dy],
          ],
        });
      });
      _changed();
    }
  }

  void move(Offset position, Size size) {
    if (!strokeActive ||
        tool == 'fill' ||
        (drawing['strokes'] as List).isEmpty) {
      return;
    }
    final logical = scene?.size ?? const Size(600, 600);
    final local = position - _boardOffset(size);
    final side = math.min(size.width, size.height);
    final points = (drawing['strokes'] as List).last['points'] as List;
    final p = [
      (local.dx / side * logical.width).clamp(0.0, logical.width),
      (local.dy / side * logical.height).clamp(0.0, logical.height),
    ];
    if (points.isNotEmpty) {
      final last = points.last;
      if ((p[0] - last[0]).abs() + (p[1] - last[1]).abs() < 1) return;
    }
    setState(() => points.add(p));
    _changed();
  }

  @override
  void dispose() {
    unawaited(save());
    saveTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) return const Center(child: CircularProgressIndicator());
    final app = widget.app;
    final controls = <Widget>[
      if (isDrawing && scene != null) _guideControls(),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            if (!isDrawing) _tool('fill', Icons.format_color_fill),
            _tool('brush', Icons.brush),
            _tool('erase', Icons.auto_fix_normal),
            if (tool == 'brush')
              Semantics(
                label: app.t('brushType'),
                child: DropdownButton<BrushStyle>(
                  key: const ValueKey('brush-style'),
                  value: brush,
                  itemHeight: 48,
                  onChanged: (value) {
                    if (value != null) setState(() => brush = value);
                  },
                  items: [
                    for (final style in BrushStyle.values)
                      DropdownMenuItem(
                        value: style,
                        child: Text(app.t('brush_${style.name}')),
                      ),
                  ],
                ),
              ),
            IconButton(
              tooltip: app.t('undo'),
              onPressed: undo.isEmpty
                  ? null
                  : () {
                      redo.add(jsonEncode(drawing));
                      setState(() => _restore(undo.removeLast()));
                      _changed();
                    },
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              tooltip: app.t('redo'),
              onPressed: redo.isEmpty
                  ? null
                  : () {
                      undo.add(jsonEncode(drawing));
                      setState(() => _restore(redo.removeLast()));
                      _changed();
                    },
              icon: const Icon(Icons.redo),
            ),
            TextButton.icon(
              key: const ValueKey('canvas-reset'),
              onPressed: canReset ? _confirmReset : null,
              icon: const Icon(Icons.restart_alt),
              label: Text(app.t('resetDrawing')),
            ),
            ..._viewportButtons(),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(app.t('colors'), maxLines: 2)),
                Flexible(
                  child: TextButton.icon(
                    key: const ValueKey('all-colors'),
                    onPressed: _allColors,
                    icon: const Icon(Icons.grid_view, size: 18),
                    label: Text(app.t('allColors'), maxLines: 2),
                  ),
                ),
              ],
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [for (var i = 0; i < colors.length; i++) _swatch(i)],
              ),
            ),
          ],
        ),
      ),
      if (tool != 'fill')
        SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(child: Text(app.t('size'), maxLines: 2)),
              SizedBox(
                width: 160,
                child: Slider(
                  min: 3,
                  max: 35,
                  value: width,
                  onChanged: (v) => setState(() => width = v),
                ),
              ),
            ],
          ),
        ),
    ];
    final surface = fullScreen
        ? _canvasSurface()
        : Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: AspectRatio(aspectRatio: 1, child: _canvasSurface()),
            ),
          );
    final board = Expanded(child: surface);
    if (fullScreen) {
      final editor = Stack(
        children: [
          Positioned.fill(child: surface),
          PositionedDirectional(
            top: 8,
            end: 8,
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Color(0x22000000)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const ValueKey('canvas-reset'),
                    tooltip: app.t('resetDrawing'),
                    onPressed: canReset ? _confirmReset : null,
                    icon: const Icon(Icons.restart_alt),
                  ),
                  ..._viewportButtons(),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${(zoom * 100).round()}%',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
      return widget.onFullScreenChanged != null
          ? editor
          : PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) {
                if (!didPop) setFullScreen(false);
              },
              child: editor,
            );
    }
    final done = Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: FilledButton.icon(
        onPressed:
            (drawing['strokes'] as List).isEmpty &&
                (drawing['fills'] as Map).isEmpty
            ? null
            : () async {
                await save();
                if (mounted) widget.onComplete();
              },
        icon: const Icon(Icons.check_circle_outline),
        label: Text(app.t('done')),
      ),
    );
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth > c.maxHeight && c.maxHeight < 500) {
          return Row(
            children: [
              SizedBox(
                width: 240,
                child: SingleChildScrollView(
                  child: Column(children: [...controls, done]),
                ),
              ),
              board,
            ],
          );
        }
        return Column(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: c.maxHeight * .5),
              child: SingleChildScrollView(child: Column(children: controls)),
            ),
            board,
            done,
          ],
        );
      },
    );
  }

  List<Widget> _viewportButtons() => [
    IconButton(
      key: const ValueKey('canvas-zoom-out'),
      tooltip: widget.app.t('zoomOut'),
      onPressed: zoom <= 1 ? null : () => zoomBy(-.25),
      icon: const Icon(Icons.remove),
    ),
    IconButton(
      key: const ValueKey('canvas-zoom-in'),
      tooltip: widget.app.t('zoomIn'),
      onPressed: zoom >= 4 ? null : () => zoomBy(.25),
      icon: const Icon(Icons.add),
    ),
    IconButton(
      key: const ValueKey('canvas-fit'),
      tooltip: widget.app.t('resetZoom'),
      onPressed: () => setState(() => transform.value = Matrix4.identity()),
      icon: const Icon(Icons.zoom_out_map),
    ),
    IconButton(
      key: const ValueKey('canvas-fullscreen'),
      tooltip: widget.app.t(fullScreen ? 'exitFullScreen' : 'fullScreen'),
      onPressed: () => setFullScreen(!fullScreen),
      icon: Icon(fullScreen ? Icons.fullscreen_exit : Icons.fullscreen),
    ),
  ];

  Widget _canvasSurface() => ClipRRect(
    borderRadius: BorderRadius.circular(fullScreen ? 0 : 24),
    child: ColoredBox(
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          _resizeViewport(size);
          final side = math.min(size.width, size.height);
          final offset = _boardOffset(size);
          return GestureDetector(
            key: const ValueKey('art-canvas'),
            behavior: HitTestBehavior.opaque,
            onTapUp: (event) {
              if (tool == 'fill' || !strokeActive) {
                start(transform.toScene(event.localPosition), size);
              }
              strokeActive = false;
              unawaited(save());
            },
            onScaleStart: (details) => scaleStart(details, size),
            onScaleUpdate: (details) => scaleUpdate(details, size),
            onScaleEnd: (_) {
              strokeActive = false;
              pinching = false;
              unawaited(save());
            },
            child: Transform(
              transform: transform.value,
              child: Stack(
                children: [
                  Positioned(
                    left: offset.dx,
                    top: offset.dy,
                    width: side,
                    height: side,
                    child: CustomPaint(
                      painter: VectorPainter(
                        scene: scene,
                        outlineOnly: true,
                        drawing: drawing,
                        guideOpacity: isDrawing ? .65 : 1,
                        guideShapes: isDrawing ? guide : null,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _tool(String name, IconData icon) => ChoiceChip(
    label: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 5),
        Text(widget.app.t(name)),
      ],
    ),
    selected: tool == name,
    onSelected: (_) => setState(() => tool = name),
  );

  void _setGuide(int value) {
    _snapshot();
    setState(() => guide = value);
    _changed();
  }

  Widget _guideControls() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        tooltip: widget.app.t('previousStep'),
        onPressed: guide > 1 ? () => _setGuide(guide - 1) : null,
        icon: const Icon(Icons.chevron_left),
      ),
      Flexible(
        child: Text(
          '${widget.app.t('step')} $guide / ${scene!.guideSteps}',
          textAlign: TextAlign.center,
        ),
      ),
      IconButton(
        tooltip: widget.app.t('nextStep'),
        onPressed: guide < scene!.guideSteps
            ? () => _setGuide(guide + 1)
            : null,
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );

  Widget _swatch(int i, {VoidCallback? onTap}) {
    final color = colors[i];
    return Semantics(
      label: '${widget.app.t('choose')} ${i + 1}',
      selected: i == selected,
      button: true,
      child: InkWell(
        onTap: onTap ?? () => setState(() => selected = i),
        borderRadius: BorderRadius.circular(50),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Color(color),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected == i
                      ? const Color(0xFF344850)
                      : const Color(0x22000000),
                  width: selected == i ? 3 : 1,
                ),
              ),
              child: selected == i
                  ? Icon(Icons.check, size: 20, color: swatchForeground(color))
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _allColors() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.app.t('allColors'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < colors.length; i++)
                    _swatch(
                      i,
                      onTap: () {
                        setState(() => selected = i);
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
