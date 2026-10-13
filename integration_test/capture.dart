import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:integration_test/integration_test.dart';

/// Bound screenshot report size without changing the device's layout or scale.
Future<List<int>> capture(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  final original = await binding.takeScreenshot(name);
  final png = Uint8List.fromList(original);
  final header = ByteData.sublistView(png);
  final width = header.getUint32(16), height = header.getUint32(20);
  var captureWidth = width, captureHeight = height;
  if (width > 1200) {
    final codec = await ui.instantiateImageCodec(png, targetWidth: 1200);
    final image = (await codec.getNextFrame()).image;
    try {
      final encoded = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      final screenshot =
          (binding.reportData!['screenshots'] as List).last as Map;
      screenshot['bytes'] = encoded.buffer.asUint8List(
        encoded.offsetInBytes,
        encoded.lengthInBytes,
      );
      captureWidth = image.width;
      captureHeight = image.height;
    } finally {
      image.dispose();
      codec.dispose();
    }
  }
  final sizes = binding.reportData!.putIfAbsent(
    'captureSizes',
    () => <String, dynamic>{},
  ) as Map;
  sizes[name] = {
    'originalWidth': width,
    'originalHeight': height,
    'captureWidth': captureWidth,
    'captureHeight': captureHeight,
  };
  return original;
}
