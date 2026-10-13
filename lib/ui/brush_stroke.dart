import 'dart:math' as math;

import 'package:flutter/material.dart';

enum BrushStyle { round, pencil, marker, crayon }

void paintBrushStroke(Canvas canvas, Map stroke) {
  final raw = stroke['points'] as List;
  if (raw.isEmpty) return;
  final points = raw
      .map((p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()))
      .toList();
  final style =
      BrushStyle.values.where((v) => v.name == stroke['brush']).firstOrNull ??
      BrushStyle.round;
  final width = (stroke['width'] as num).toDouble();
  final color = Color(stroke['color'] as int);
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (final point in points.skip(1)) {
    path.lineTo(point.dx, point.dy);
  }
  final paint = Paint()
    ..color = color
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;
  switch (style) {
    case BrushStyle.round:
      break;
    case BrushStyle.pencil:
      paint
        ..strokeWidth = width * .35
        ..color = color.withValues(alpha: color.a * .85);
    case BrushStyle.marker:
      paint
        ..strokeWidth = width * 1.3
        ..strokeCap = StrokeCap.square
        ..color = color.withValues(alpha: color.a * .45);
    case BrushStyle.crayon:
      paint
        ..strokeWidth = width * .8
        ..color = color.withValues(alpha: color.a * .3);
  }
  if (points.length == 1) {
    final bounds = Rect.fromCircle(
      center: points.first,
      radius: paint.strokeWidth / 2,
    );
    final dab = Paint()..color = paint.color;
    if (style == BrushStyle.marker) {
      canvas.drawRect(bounds, dab);
    } else {
      canvas.drawOval(bounds, dab);
    }
  } else {
    canvas.drawPath(path, paint);
  }
  if (style != BrushStyle.crayon) return;

  // Fixed grain positions make saved strokes and live previews identical.
  var seed = 713;
  double random() {
    seed = (seed * 1664525 + 1013904223) & 0xffffffff;
    return seed / 0x100000000;
  }

  final grain = Path();
  void stamp(Offset center) {
    for (var i = 0; i < 8; i++) {
      final angle = random() * math.pi * 2;
      final radius = math.sqrt(random()) * width * .42;
      final dot = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      grain.addOval(
        Rect.fromCircle(center: dot, radius: width * (.025 + random() * .04)),
      );
    }
  }

  stamp(points.first);
  final spacing = math.max(1.5, width * .2);
  var untilNext = spacing;
  for (var i = 1; i < points.length; i++) {
    final delta = points[i] - points[i - 1];
    final length = delta.distance;
    if (length == 0) continue;
    while (untilNext <= length) {
      stamp(points[i - 1] + delta * (untilNext / length));
      untilNext += spacing;
    }
    untilNext -= length;
  }
  canvas.drawPath(
    grain,
    Paint()..color = color.withValues(alpha: color.a * .8),
  );
}
