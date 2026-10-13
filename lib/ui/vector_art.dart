import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import 'brush_stroke.dart';

Color hexColor(String hex) => Color(int.parse('FF$hex', radix: 16));

class ArtShape {
  final String id;
  final Path path;
  final Color color;
  final bool fillable;
  final bool strokeOnly, outlined;
  final double? strokeWidth;
  ArtShape(
    this.id,
    this.path,
    this.color,
    this.fillable, {
    this.strokeOnly = false,
    this.outlined = true,
    this.strokeWidth,
  });
}

class VectorScene {
  final Size size;
  final List<ArtShape> shapes;
  final double strokeWidth;
  VectorScene(this.size, this.shapes, {this.strokeWidth = 1.7});
  int get guideSteps => shapes.where((s) => s.outlined || s.strokeOnly).length;
  factory VectorScene.fromJson(Map<String, dynamic> data) {
    final shapes = <ArtShape>[];
    for (final (index, raw) in (data['shapes'] as List).indexed) {
      final v = (raw['v'] as List? ?? []).cast<dynamic>();
      Path p = Path();
      switch (raw['kind']) {
        case 'ellipse':
          p.addOval(
            Rect.fromLTWH(
              (v[0] as num).toDouble(),
              (v[1] as num).toDouble(),
              (v[2] as num).toDouble(),
              (v[3] as num).toDouble(),
            ),
          );
        case 'rect':
          p.addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                (v[0] as num).toDouble(),
                (v[1] as num).toDouble(),
                (v[2] as num).toDouble(),
                (v[3] as num).toDouble(),
              ),
              Radius.circular((v[4] as num).toDouble()),
            ),
          );
        case 'poly':
          for (final (i, point) in v.indexed) {
            if (i == 0) {
              p.moveTo(
                (point[0] as num).toDouble(),
                (point[1] as num).toDouble(),
              );
            } else {
              p.lineTo(
                (point[0] as num).toDouble(),
                (point[1] as num).toDouble(),
              );
            }
          }
          p.close();
        case 'path':
        case 'stroke':
          p = parseSvgPathData(raw['d']);
      }
      if (raw['transform'] != null) {
        final t = raw['transform'];
        final matrix = Matrix4.identity()
          ..translateByDouble(
            (t[0] as num).toDouble(),
            (t[1] as num).toDouble(),
            0,
            1,
          )
          ..scaleByDouble(
            (t[2] as num).toDouble(),
            (t[2] as num).toDouble(),
            1,
            1,
          );
        p = p.transform(matrix.storage);
      }
      shapes.add(
        ArtShape(
          raw['id'] ?? 'r$index',
          p,
          hexColor(raw['color'] ?? '75BFCB'),
          raw['kind'] != 'stroke' && raw['fillable'] != false,
          strokeOnly: raw['kind'] == 'stroke',
          outlined: raw['outline'] != false,
          strokeWidth: raw['strokeWidth'] == null
              ? null
              : (raw['strokeWidth'] as num).toDouble() *
                    (raw['transform']?[2] ?? 1),
        ),
      );
    }
    return VectorScene(
      Size(
        (data['width'] as num).toDouble(),
        (data['height'] as num).toDouble(),
      ),
      shapes,
      strokeWidth:
          (data['strokeWidth'] as num?)?.toDouble() ??
          (data['width'] as num) / 200 * 1.7,
    );
  }
  final _visiblePaths = <String, Path>{};
  Path visiblePath(String id) => _visiblePaths.putIfAbsent(id, () {
    final index = shapes.indexWhere((s) => s.id == id);
    if (index < 0) return Path();
    var path = shapes[index].path;
    for (final shape in shapes.skip(index + 1)) {
      if (shape.strokeOnly) continue;
      path = Path.combine(PathOperation.difference, path, shape.path);
    }
    return path;
  });
  String? regionAt(Offset position) {
    for (final s in shapes.reversed) {
      if (s.strokeOnly) continue;
      if (s.path.contains(position)) return s.fillable ? s.id : null;
    }
    return null;
  }
}

final _scenes = Expando<Map<String, VectorScene>>();
VectorScene? sceneFor(Map<String, dynamic> art, String? id) {
  if (id == null || !art.containsKey(id)) return null;
  final cache = _scenes[art] ??= <String, VectorScene>{};
  return cache.putIfAbsent(
    id,
    () => VectorScene.fromJson(Map<String, dynamic>.from(art[id])),
  );
}

class ArtThumbnail extends StatelessWidget {
  final VectorScene? scene;
  final bool outlined;
  const ArtThumbnail({super.key, required this.scene, this.outlined = false});
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: VectorPainter(scene: scene, outlineOnly: outlined),
    child: const SizedBox.expand(),
  );
}

class VectorPainter extends CustomPainter {
  final VectorScene? scene;
  final bool outlineOnly;
  final Map<String, dynamic>? drawing;
  final double guideOpacity;
  final int? guideShapes;
  VectorPainter({
    required this.scene,
    this.outlineOnly = false,
    this.drawing,
    this.guideOpacity = 1,
    this.guideShapes,
  });
  void drawScene(Canvas canvas, Size size) {
    final logical = scene?.size ?? const Size(600, 600);
    canvas.save();
    canvas.scale(size.width / logical.width, size.height / logical.height);
    final fills = drawing?['fills'] as Map? ?? {};
    final shapes = scene?.shapes ?? <ArtShape>[];
    final strokes = drawing?['strokes'] as List? ?? [];
    final byRegion = <String, List<dynamic>>{};
    final freeStrokes = <dynamic>[];
    for (final stroke in strokes) {
      final region = stroke['region'];
      if (region is String && shapes.any((s) => s.id == region)) {
        (byRegion[region] ??= []).add(stroke);
      } else {
        freeStrokes.add(stroke);
      }
    }
    void drawStroke(dynamic stroke, {Path? clip}) {
      canvas.save();
      if (clip != null) canvas.clipPath(clip);
      paintBrushStroke(canvas, stroke);
      canvas.restore();
    }

    var step = 0;
    for (final shape in shapes) {
      if (shape.outlined || shape.strokeOnly) step++;
      final opacity = guideShapes != null && step > guideShapes!
          ? guideOpacity * .45
          : guideOpacity;
      if (shape.strokeOnly) {
        canvas.drawPath(
          shape.path,
          Paint()
            ..color = (outlineOnly ? const Color(0xFF344850) : shape.color)
                .withValues(alpha: opacity)
            ..strokeWidth = shape.strokeWidth ?? scene!.strokeWidth
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..style = PaintingStyle.stroke,
        );
        continue;
      }
      Color color = shape.fillable
          ? (fills[shape.id] != null
                ? Color(fills[shape.id])
                : (outlineOnly ? Colors.white : shape.color))
          : shape.color;
      canvas.drawPath(
        shape.path,
        Paint()..color = color.withValues(alpha: outlineOnly ? 1 : opacity),
      );
      for (final stroke in byRegion[shape.id] ?? []) {
        drawStroke(stroke, clip: shape.path);
      }
      if (!shape.outlined) continue;
      canvas.drawPath(
        shape.path,
        Paint()
          ..color = const Color(0xFF344850).withValues(alpha: opacity)
          ..strokeWidth = shape.strokeWidth ?? scene!.strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    for (final stroke in freeStrokes) {
      drawStroke(stroke);
    }
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) => drawScene(canvas, size);
  @override
  bool shouldRepaint(covariant VectorPainter old) => true;
}

Future<ui.Image> renderArtwork(
  VectorScene? scene,
  Map<String, dynamic> drawing, {
  int pixels = 1200,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(Colors.white, BlendMode.src);
  VectorPainter(
    scene: scene,
    drawing: drawing,
    outlineOnly: true,
  ).drawScene(canvas, Size(pixels.toDouble(), pixels.toDouble()));
  final picture = recorder.endRecording();
  final image = await picture.toImage(pixels, pixels);
  picture.dispose();
  return image;
}
