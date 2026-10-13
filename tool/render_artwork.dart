import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pikolumi/core/models.dart';
import 'package:pikolumi/ui/vector_art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('render the full art library for visual review', () async {
    final catalog = await Catalog.load();
    final directory = Directory('docs/qa/art-review/images');
    await directory.create(recursive: true);
    for (final id in catalog.art.keys) {
      final scene = sceneFor(catalog.art, id)!;
      for (final outlined
          in id.startsWith('scene_') ? [false, true] : [false]) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawColor(Colors.white, BlendMode.src);
        VectorPainter(
          scene: scene,
          outlineOnly: outlined,
        ).drawScene(canvas, const Size(360, 360));
        final picture = recorder.endRecording();
        final image = await picture.toImage(360, 360);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('${directory.path}/$id${outlined ? '-outline' : ''}.png')
            .writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
      }
    }
    debugPrint(
      'Rendered 576 illustrations and 360 coloring outlines without sound.',
    );
  });
}
