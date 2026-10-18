import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui/listen.dart';
import 'learning.dart';
import 'trace_geometry.dart';

class TraceActivity extends StatefulWidget {
  final EngineContext engine;
  const TraceActivity({super.key, required this.engine});
  @override
  State<TraceActivity> createState() => _TraceActivityState();
}

class _TraceActivityState extends State<TraceActivity> {
  EngineContext get e => widget.engine;
  late List<List<Offset>> strokes;
  int stroke = 0, at = 0;
  bool finished = false, dragging = false;
  Map<String, dynamic>? migration;
  @override
  void initState() {
    super.initState();
    strokes = tracePoints(e.config['strokes'] as List);
    final checkpoint = TraceCheckpoint.restore(e.config, strokes, e.resume);
    stroke = checkpoint.stroke;
    at = checkpoint.at;
    migration = checkpoint.previous;
  }

  void save() => e.save({
    'stroke': stroke,
    'at': at,
    'traceRevision': e.config['traceRevision'] ?? 1,
    if (migration != null) 'traceMigration': migration,
  });

  void touch(Offset p, Size size) {
    if (finished) return;
    final logical = TraceViewport(size).logical(p);
    final points = strokes[stroke];
    final shortStroke = points.length <= 4;
    if (!dragging && (logical - points[at]).distance > 24) return;
    dragging = true;
    var nearest = at;
    double distance = 24;
    for (var i = at; i < math.min(at + 12, points.length); i++) {
      final d = (logical - points[i]).distance;
      if (d < distance) {
        nearest = i;
        distance = d;
      }
    }
    if (nearest == at && !(at == 0 && shortStroke)) return;
    if (shortStroke && at == 0) nearest = points.length - 1;
    setState(() => at = nearest);
    if (at >= points.length - 2) {
      if (stroke == strokes.length - 1) {
        finished = true;
      } else {
        setState(() {
          stroke++;
          at = 0;
          dragging = false;
        });
      }
    }
    e.onProgress?.call();
    save();
    if (finished) e.complete();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final landscape =
          constraints.maxHeight < 300 &&
          constraints.maxWidth > constraints.maxHeight;
      final step = Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          '${e.app.t('step')} ${stroke + 1} / ${strokes.length}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      );
      final Widget model = (e.config['glyph'] ?? '').toString().isEmpty
          ? const SizedBox.shrink()
          : (((e.config['traceRevision'] as int?) ?? 1) >= 2)
          ? Semantics(
              label: e.config['glyph'],
              child: SizedBox(
                width:
                    (e.config['modelWidth'] as num?)?.toDouble() ??
                    (e.config['arabicLesson'] == 'word' ? 180 : 92),
                height: landscape ? 56 : 80,
                child: RepaintBoundary(
                  child: CustomPaint(
                    key: const ValueKey('trace-model'),
                    painter: TracePainter(
                      strokes,
                      stroke,
                      at,
                      guideWidth: (e.config['guideWidth'] as num).toDouble(),
                      preview: true,
                      kinds: (e.config['strokeKinds'] as List).cast<String>(),
                    ),
                  ),
                ),
              ),
            )
          : Text(
              e.config['glyph'],
              textDirection: e.config['direction'] == 'rtl'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                fontFamily: e.contentFont,
              ),
            );
      final board = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: AspectRatio(
            aspectRatio: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: ColoredBox(
                  color: Colors.white,
                  child: LayoutBuilder(
                    builder: (context, c) {
                      return GestureDetector(
                        key: const ValueKey('trace-canvas'),
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (d) => touch(d.localPosition, c.biggest),
                        onPanUpdate: (d) => touch(d.localPosition, c.biggest),
                        onPanEnd: (_) => dragging = false,
                        onTapUp: (d) => touch(d.localPosition, c.biggest),
                        child: CustomPaint(
                          painter: TracePainter(
                            strokes,
                            stroke,
                            at,
                            guideWidth:
                                (e.config['guideWidth'] as num?)?.toDouble() ??
                                13,
                            kinds: (e.config['strokeKinds'] as List?)
                                ?.cast<String>(),
                          ),
                          child: const SizedBox.expand(),
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
      final reset = TextButton.icon(
        onPressed: () {
          setState(() {
            stroke = 0;
            at = 0;
            dragging = false;
            finished = false;
          });
          save();
          unawaited(playActivityPrompt(e.app, e.activity));
        },
        icon: const Icon(Icons.replay),
        label: Text(e.app.t('again')),
      );
      if (landscape) {
        return Row(
          children: [
            SizedBox(
              width: math.min(280, constraints.maxWidth * .4),
              child: SingleChildScrollView(
                child: Column(
                  children: [step, model, const SizedBox(height: 8), reset],
                ),
              ),
            ),
            Expanded(child: board),
          ],
        );
      }
      return Column(
        children: [
          step,
          model,
          Expanded(child: board),
          reset,
        ],
      );
    },
  );
}

class TracePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final int stroke, at;
  final double guideWidth;
  final bool preview;
  final List<String>? kinds;
  TracePainter(
    this.strokes,
    this.stroke,
    this.at, {
    this.guideWidth = 13,
    this.preview = false,
    this.kinds,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final viewport = TraceViewport(size);
    if (preview) {
      final points = strokes.expand((path) => path);
      final bounds = Rect.fromLTRB(
        points.map((p) => p.dx).reduce(math.min),
        points.map((p) => p.dy).reduce(math.min),
        points.map((p) => p.dx).reduce(math.max),
        points.map((p) => p.dy).reduce(math.max),
      ).inflate(guideWidth);
      final scale = math.min(
        size.width / bounds.width,
        size.height / bounds.height,
      );
      canvas.translate(size.width / 2, size.height / 2);
      canvas.scale(scale);
      canvas.translate(-bounds.center.dx, -bounds.center.dy);
    } else {
      canvas.translate(viewport.origin.dx, viewport.origin.dy);
      canvas.scale(viewport.scale);
    }
    final guide = Paint()
      ..color = preview ? const Color(0xFF344850) : const Color(0xFF9586A5)
      ..strokeWidth = guideWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final ink = Paint()
      ..color = const Color(0xFF328E9D)
      ..strokeWidth = guideWidth * .7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    Path path(List<Offset> points) {
      final p = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        p.lineTo(point.dx, point.dy);
      }
      return p;
    }

    for (var i = 0; i < strokes.length; i++) {
      if (kinds?[i] == 'dot') {
        final center = Offset.lerp(strokes[i].first, strokes[i].last, .5)!;
        canvas.drawCircle(
          center,
          guideWidth * .58,
          guide..style = PaintingStyle.fill,
        );
        guide.style = PaintingStyle.stroke;
        if (!preview && i < stroke) {
          canvas.drawCircle(
            center,
            guideWidth * .5,
            ink..style = PaintingStyle.fill,
          );
          ink.style = PaintingStyle.stroke;
        }
        continue;
      }
      canvas.drawPath(path(strokes[i]), guide);
      if (!preview && i < stroke) canvas.drawPath(path(strokes[i]), ink);
      if (!preview && i == stroke && at > 0) {
        canvas.drawPath(path(strokes[i].take(at + 1).toList()), ink);
      }
    }
    if (preview) return;
    final p = strokes[stroke][at];
    canvas.drawCircle(p, 12, Paint()..color = const Color(0xFFF3C65F));
    canvas.drawCircle(p, 4, Paint()..color = const Color(0xFF344850));
    if (at + 5 < strokes[stroke].length) {
      final to = strokes[stroke][at + 5];
      final d = (to - p);
      if (d.distance > 0) {
        final u = d / d.distance;
        final v = Offset(-u.dy, u.dx);
        canvas.drawLine(
          p + u * 16,
          p + u * 24,
          Paint()
            ..color = const Color(0xFF344850)
            ..strokeWidth = 2,
        );
        canvas.drawLine(
          p + u * 24,
          p + u * 19 + v * 4,
          Paint()
            ..color = const Color(0xFF344850)
            ..strokeWidth = 2,
        );
        canvas.drawLine(
          p + u * 24,
          p + u * 19 - v * 4,
          Paint()
            ..color = const Color(0xFF344850)
            ..strokeWidth = 2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(TracePainter old) =>
      (!preview && (old.stroke != stroke || old.at != at)) ||
      old.strokes != strokes ||
      old.guideWidth != guideWidth ||
      old.preview != preview;
}

class MazeActivity extends StatefulWidget {
  final EngineContext engine;
  const MazeActivity({super.key, required this.engine});
  @override
  State<MazeActivity> createState() => _MazeActivityState();
}

class _MazeActivityState extends State<MazeActivity> {
  EngineContext get e => widget.engine;
  int position = 0;
  bool hint = false, finished = false;
  late List<int> trail;
  int get n => e.config['size'];
  List<List<int>> get walls =>
      (e.config['walls'] as List).map((j) => (j as List).cast<int>()).toList();
  @override
  void initState() {
    super.initState();
    position = e.resume?['position'] ?? 0;
    trail = (e.resume?['trail'] as List? ?? [0]).cast<int>();
  }

  void move(int direction) {
    if (finished || walls[position][direction] != 0) return;
    final next = position + [-n, 1, n, -1][direction];
    setState(() {
      position = next;
      trail.add(next);
    });
    e.onProgress?.call();
    e.save({'position': position, 'trail': trail});
    if (position == e.config['finish']) {
      finished = true;
      e.complete();
    }
  }

  void tap(Offset p, Size size) {
    final x = (p.dx / size.width * n).floor(),
        y = (p.dy / size.height * n).floor();
    if (x < 0 || x >= n || y < 0 || y >= n) return;
    final target = y * n + x;
    final delta = target - position;
    if (delta == -n) move(0);
    if (delta == 1 && x > 0) move(1);
    if (delta == n) move(2);
    if (delta == -1 && x < n - 1) move(3);
  }

  List<int> solve() {
    final queue = [position];
    final previous = <int, int>{position: -1};
    final w = walls;
    for (var head = 0; head < queue.length; head++) {
      final v = queue[head];
      if (v == e.config['finish']) break;
      for (var d = 0; d < 4; d++) {
        final to = v + [-n, 1, n, -1][d];
        if (w[v][d] == 0 && !previous.containsKey(to)) {
          previous[to] = v;
          queue.add(to);
        }
      }
    }
    final route = <int>[];
    var at = e.config['finish'] as int;
    while (at != -1) {
      route.add(at);
      at = previous[at] ?? -1;
    }
    return route.reversed.toList();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: AspectRatio(
              aspectRatio: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, c) => GestureDetector(
                    onTapUp: (d) => tap(d.localPosition, c.biggest),
                    onPanUpdate: (d) => tap(d.localPosition, c.biggest),
                    child: CustomPaint(
                      painter: MazePainter(
                        n,
                        walls,
                        position,
                        trail,
                        hint ? solve() : [],
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            _arrow(0, Icons.arrow_upward),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _arrow(3, Icons.arrow_back),
                const SizedBox(width: 60),
                _arrow(1, Icons.arrow_forward),
              ],
            ),
            _arrow(2, Icons.arrow_downward),
          ],
        ),
      ),
      TextButton.icon(
        onPressed: () => setState(() => hint = !hint),
        icon: const Icon(Icons.lightbulb_outline),
        label: Text(e.app.t('hint')),
      ),
    ],
  );
  Widget _arrow(int d, IconData icon) => IconButton.filledTonal(
    tooltip: [
      e.app.t('up'),
      e.app.t('right'),
      e.app.t('down'),
      e.app.t('left'),
    ][d],
    key: ValueKey('maze-$d'),
    onPressed: () => move(d),
    icon: Icon(icon),
    style: IconButton.styleFrom(minimumSize: const Size(56, 56)),
  );
}

class MazePainter extends CustomPainter {
  final int n, position;
  final List<List<int>> walls;
  final List<int> trail, solution;
  MazePainter(this.n, this.walls, this.position, this.trail, this.solution);
  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / n;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      Paint()..color = Colors.white,
    );
    Offset center(int i) => Offset((i % n + .5) * cell, (i ~/ n + .5) * cell);
    void route(List<int> points, Color color) {
      if (points.isEmpty) return;
      final p = Path()
        ..moveTo(center(points.first).dx, center(points.first).dy);
      for (final i in points.skip(1)) {
        p.lineTo(center(i).dx, center(i).dy);
      }
      canvas.drawPath(
        p,
        Paint()
          ..color = color
          ..strokeWidth = cell * .22
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }

    route(trail, const Color(0xFFE2EEED));
    route(solution, const Color(0xFFFFE6A0));
    final pen = Paint()
      ..color = const Color(0xFF667582)
      ..strokeWidth = math.max(2, cell * .045)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < n * n; i++) {
      final x = i % n * cell, y = i ~/ n * cell;
      if (walls[i][0] == 1) {
        canvas.drawLine(Offset(x, y), Offset(x + cell, y), pen);
      }
      if (walls[i][1] == 1) {
        canvas.drawLine(Offset(x + cell, y), Offset(x + cell, y + cell), pen);
      }
      if (walls[i][2] == 1) {
        canvas.drawLine(Offset(x, y + cell), Offset(x + cell, y + cell), pen);
      }
      if (walls[i][3] == 1) {
        canvas.drawLine(Offset(x, y), Offset(x, y + cell), pen);
      }
    }
    canvas.drawCircle(
      center(n * n - 1),
      cell * .25,
      Paint()..color = const Color(0xFFF3C65F),
    );
    canvas.drawCircle(
      center(position),
      cell * .26,
      Paint()..color = const Color(0xFF74BEC6),
    );
    canvas.drawCircle(
      center(position) + Offset(cell * .06, -cell * .05),
      cell * .055,
      Paint()..color = const Color(0xFF344850),
    );
  }

  @override
  bool shouldRepaint(MazePainter old) =>
      old.position != position || old.solution.length != solution.length;
}
