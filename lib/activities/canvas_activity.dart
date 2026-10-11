import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/controller.dart';
import '../core/models.dart';
import '../ui/vector_art.dart';

class CanvasActivity extends StatefulWidget {
  final Activity activity;
  final AppController app;
  final VoidCallback onComplete;
  const CanvasActivity({
    super.key,
    required this.activity,
    required this.app,
    required this.onComplete,
  });
  @override
  State<CanvasActivity> createState() => CanvasActivityState();
}

class CanvasActivityState extends State<CanvasActivity>
    with WidgetsBindingObserver {
  Map<String, dynamic> drawing = {
    'fills': <String, dynamic>{},
    'strokes': <dynamic>[],
  };
  final List<String> undo = [], redo = [];
  final TransformationController transform = TransformationController();
  String tool = 'fill';
  int selected = 0;
  double width = 12;
  int guide = 1;
  bool loaded = false, dirty = false, strokeActive = false;
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
  ];
  Map<String, dynamic> get config =>
      widget.activity.config(widget.app.language);
  VectorScene? get scene => sceneFor(widget.app.catalog.art, config['scene']);
  bool get isDrawing => config['mode'] == 'drawing';
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
        guide = drawing['guide'] ?? 1;
      }
      loaded = true;
    });
  }

  void _snapshot() {
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
  Offset pinchAnchor = Offset.zero;
  double pinchScale = 1, gestureScale = 1;
  void scaleStart(ScaleStartDetails details, Size size) {
    pinching = false;
    dirtyBeforeGesture = dirty;
    if (details.pointerCount == 1 && tool != 'fill') {
      start(transform.toScene(details.localFocalPoint), size);
    }
  }

  void scaleUpdate(ScaleUpdateDetails details, Size size) {
    if (details.pointerCount > 1) {
      if (!pinching) {
        if (strokeActive && undo.isNotEmpty) {
          drawing = Map<String, dynamic>.from(jsonDecode(undo.removeLast()));
          dirty = dirtyBeforeGesture;
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
      final dx = (details.localFocalPoint.dx - pinchAnchor.dx * factor).clamp(
        size.width * (1 - factor),
        0.0,
      );
      final dy = (details.localFocalPoint.dy - pinchAnchor.dy * factor).clamp(
        size.height * (1 - factor),
        0.0,
      );
      setState(
        () => transform.value = Matrix4.identity()
          ..translateByDouble(dx, dy, 0, 1)
          ..scaleByDouble(factor, factor, 1, 1),
      );
    } else if (!pinching && tool != 'fill') {
      move(transform.toScene(details.localFocalPoint), size);
    }
  }

  void start(Offset position, Size size) {
    strokeActive = false;
    if (!loaded) return;
    final logical = scene?.size ?? const Size(600, 600);
    final p = Offset(
      position.dx / size.width * logical.width,
      position.dy / size.height * logical.height,
    );
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
    final points = (drawing['strokes'] as List).last['points'] as List;
    final p = [
      (position.dx / size.width * logical.width).clamp(0.0, logical.width),
      (position.dy / size.height * logical.height).clamp(0.0, logical.height),
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
            IconButton(
              tooltip: app.t('undo'),
              onPressed: undo.isEmpty
                  ? null
                  : () {
                      redo.add(jsonEncode(drawing));
                      setState(
                        () => drawing = Map<String, dynamic>.from(
                          jsonDecode(undo.removeLast()),
                        ),
                      );
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
                      setState(
                        () => drawing = Map<String, dynamic>.from(
                          jsonDecode(redo.removeLast()),
                        ),
                      );
                      _changed();
                    },
              icon: const Icon(Icons.redo),
            ),
            IconButton(
              tooltip: app.t('resetZoom'),
              onPressed: () => transform.value = Matrix4.identity(),
              icon: const Icon(Icons.zoom_out_map),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Wrap(
          spacing: 7,
          runSpacing: 7,
          alignment: WrapAlignment.center,
          children: [
            for (final (i, color) in colors.indexed)
              Semantics(
                label: '${app.t('choose')} ${i + 1}',
                selected: i == selected,
                button: true,
                child: InkWell(
                  onTap: () => setState(() => selected = i),
                  borderRadius: BorderRadius.circular(50),
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
                        ? Icon(
                            Icons.check,
                            size: 20,
                            color: color == 0xFF344850
                                ? Colors.white
                                : const Color(0xFF344850),
                          )
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
      if (tool != 'fill')
        SizedBox(
          height: 46,
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
      if (isDrawing && scene != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: guide > 1 ? () => setState(() => guide--) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${app.t('step')} $guide / ${scene!.shapes.length}'),
              IconButton(
                onPressed: guide < scene!.shapes.length
                    ? () => setState(() => guide++)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
    ];
    final board = Expanded(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: ColoredBox(
                color: Colors.white,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = constraints.biggest;
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
                        child: CustomPaint(
                          painter: VectorPainter(
                            scene: scene,
                            outlineOnly: true,
                            drawing: drawing,
                            guideOpacity: isDrawing ? .23 : 1,
                            guideShapes: isDrawing ? guide : null,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final done = Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: FilledButton.icon(
        onPressed:
            !dirty &&
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
              constraints: BoxConstraints(maxHeight: c.maxHeight * .44),
              child: SingleChildScrollView(child: Column(children: controls)),
            ),
            board,
            done,
          ],
        );
      },
    );
  }

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
}
