import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

Color hexColor(String hex) => Color(int.parse('FF$hex', radix: 16));

class ArtShape {
  final String id;
  final Path path;
  final Color color;
  final bool fillable;
  ArtShape(this.id, this.path, this.color, this.fillable);
}

class VectorScene {
  final Size size;
  final List<ArtShape> shapes;
  VectorScene(this.size, this.shapes);
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
          raw['fillable'] != false,
        ),
      );
    }
    return VectorScene(
      Size(
        (data['width'] as num).toDouble(),
        (data['height'] as num).toDouble(),
      ),
      shapes,
    );
  }
  final _visiblePaths = <String, Path>{};
  Path visiblePath(String id) => _visiblePaths.putIfAbsent(id, () {
    final index = shapes.indexWhere((s) => s.id == id);
    if (index < 0) return Path();
    var path = shapes[index].path;
    for (final shape in shapes.skip(index + 1)) {
      path = Path.combine(PathOperation.difference, path, shape.path);
    }
    return path;
  });
  String? regionAt(Offset position) {
    for (final s in shapes.reversed) {
      if (s.path.contains(position)) return s.fillable ? s.id : null;
    }
    return null;
  }
}

final _scenes = <String, VectorScene>{};
VectorScene? sceneFor(Map<String, dynamic> art, String? id) {
  if (id == null || !art.containsKey(id)) return null;
  return _scenes.putIfAbsent(
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
    for (final (i, shape) in shapes.indexed) {
      if (guideShapes != null && i >= guideShapes!) continue;
      Color color = shape.fillable
          ? (fills[shape.id] != null
                ? Color(fills[shape.id])
                : (outlineOnly ? Colors.white : shape.color))
          : shape.color;
      canvas.drawPath(
        shape.path,
        Paint()..color = color.withValues(alpha: guideOpacity),
      );
    }
    for (final stroke in drawing?['strokes'] as List? ?? []) {
      final points = stroke['points'] as List;
      if (points.isEmpty) continue;
      final path = Path()
        ..moveTo(
          (points.first[0] as num).toDouble(),
          (points.first[1] as num).toDouble(),
        );
      for (final point in points.skip(1)) {
        path.lineTo((point[0] as num).toDouble(), (point[1] as num).toDouble());
      }
      final color = Color(stroke['color']);
      final paint = Paint()
        ..color = color
        ..strokeWidth = (stroke['width'] as num).toDouble()
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      canvas.save();
      final region = stroke['region'];
      if (region != null) {
        final targets = shapes.where((s) => s.id == region);
        if (targets.isNotEmpty) canvas.clipPath(scene!.visiblePath(region));
      }
      if (points.length == 1) {
        canvas.drawCircle(
          Offset(
            (points.first[0] as num).toDouble(),
            (points.first[1] as num).toDouble(),
          ),
          paint.strokeWidth / 2,
          Paint()..color = color,
        );
      } else {
        canvas.drawPath(path, paint);
      }
      canvas.restore();
    }
    for (final (i, shape) in shapes.indexed) {
      if (guideShapes != null && i >= guideShapes!) continue;
      canvas.drawPath(
        shape.path,
        Paint()
          ..color = const Color(0xFF344850).withValues(alpha: guideOpacity)
          ..strokeWidth = (logical.width / 200) * 1.7
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round,
      );
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
