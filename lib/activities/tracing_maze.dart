import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'learning.dart';

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
  @override
  void initState() {
    super.initState();
    strokes = (e.config['strokes'] as List).map((raw) {
      final vertices = (raw as List)
          .map(
            (p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
          )
          .toList();
      final points = <Offset>[];
      for (var i = 0; i < vertices.length - 1; i++) {
        final n = math.max(
          1,
          ((vertices[i + 1] - vertices[i]).distance / 5).ceil(),
        );
        for (var j = 0; j < n; j++) {
          points.add(Offset.lerp(vertices[i], vertices[i + 1], j / n)!);
        }
      }
      points.add(vertices.last);
      return points;
    }).toList();
    stroke = (e.resume?['stroke'] ?? 0).clamp(0, strokes.length - 1);
    at = (e.resume?['at'] ?? 0).clamp(0, strokes[stroke].length - 1);
  }

  void touch(Offset p, Size size) {
    if (finished) return;
    final logical = Offset(p.dx / size.width * 220, p.dy / size.height * 220);
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
        e.complete();
      } else {
        setState(() {
          stroke++;
          at = 0;
          dragging = false;
        });
      }
    }
    e.save({'stroke': stroke, 'at': at});
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          '${e.app.t('step')} ${stroke + 1} / ${strokes.length}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ),
      if ((e.config['glyph'] ?? '').toString().isNotEmpty)
        Text(
          e.config['glyph'],
          textDirection: e.config['direction'] == 'rtl'
              ? TextDirection.rtl
              : TextDirection.ltr,
          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800),
        ),
      Expanded(
        child: Center(
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
                            painter: TracePainter(strokes, stroke, at),
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
        ),
      ),
      TextButton.icon(
        onPressed: () {
          setState(() {
            stroke = 0;
            at = 0;
            dragging = false;
          });
          e.save({'stroke': 0, 'at': 0});
        },
        icon: const Icon(Icons.replay),
        label: Text(e.app.t('again')),
      ),
    ],
  );
}

class TracePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final int stroke, at;
  TracePainter(this.strokes, this.stroke, this.at);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 220, size.height / 220);
    final guide = Paint()
      ..color = const Color(0xFFE2DFEA)
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final ink = Paint()
      ..color = const Color(0xFF74BEC6)
      ..strokeWidth = 9
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
      canvas.drawPath(path(strokes[i]), guide);
      if (i < stroke) canvas.drawPath(path(strokes[i]), ink);
      if (i == stroke && at > 0) {
        canvas.drawPath(path(strokes[i].take(at + 1).toList()), ink);
      }
    }
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
  bool shouldRepaint(TracePainter old) => old.stroke != stroke || old.at != at;
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
