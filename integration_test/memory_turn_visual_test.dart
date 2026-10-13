import 'dart:io';
import 'dart:typed_data';

import 'capture.dart';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pikolumi/core/controller.dart';
import 'package:pikolumi/core/models.dart';
import 'package:pikolumi/main.dart';
import 'package:pikolumi/services/ads.dart';
import 'package:pikolumi/ui/activity_screen.dart';

import '../test/app_test.dart' show MemoryStore, SilentAudio;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('turning card has no flat press highlight behind it', (
    tester,
  ) async {
    final app = AppController(
      catalog: await Catalog.load(),
      store: MemoryStore(),
      audio: SilentAudio(),
    );
    await app.initialize();
    await app.setSound(false);
    final ads = AdsService(app.store, app.audio);
    final container = ProviderContainer(
      overrides: [appProvider.overrideWith((ref) => app)],
    );
    var ticking = true;
    late StateSetter update;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return TickerMode(
              enabled: ticking,
              child: PikolumiApp(ads: ads),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
    }
    final differences = <String, int>{};
    for (final locale in ['en', 'ar']) {
      await app.setLanguage(locale);
      await tester.pumpAndSettle();
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => ActivityScreen(
            activity: app.catalog.bySection['memory']!.first,
            ads: ads,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('memory-0'));
      await tester.tap(card);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      update(() => ticking = false);
      await tester.pump();
      final angle = tester
          .widget<Transform>(
            find.descendant(of: card, matching: find.byType(Transform)).first,
          )
          .transform
          .entry(0, 0);
      expect(angle.abs(), lessThan(.85));
      final rect = tester.getRect(card);
      final bytes = await capture(binding, '$locale-card-turn-final');
      final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
      final im = (await codec.getNextFrame()).image;
      final data = (await im.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final sx =
          im.width /
          tester.view.physicalSize.width *
          tester.view.devicePixelRatio;
      final sy =
          im.height /
          tester.view.physicalSize.height *
          tester.view.devicePixelRatio;
      List<int> pixel(double x, double y) {
        final i = (y * sy).round() * im.width * 4 + (x * sx).round() * 4;
        return [data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2)];
      }

      final empty = pixel(rect.left + rect.width * .025, rect.center.dy);
      final background = pixel(rect.center.dx, rect.top - 8);
      final difference = List.generate(
        3,
        (i) => (empty[i] - background[i]).abs(),
      ).reduce((a, b) => a > b ? a : b);
      differences[locale] = difference;
      expect(
        difference,
        lessThanOrEqualTo(14),
        reason: 'The exposed card slot should retain the page background',
      );
      im.dispose();
      codec.dispose();
      update(() => ticking = true);
      await tester.pump();
      await tester.pumpAndSettle();
      navigator.pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    binding.reportData = {
      ...?binding.reportData,
      'locales': ['en', 'ar'],
      'clearExposedSlotVerified': true,
      'backgroundDifferences': differences,
      'audio': 'SilentAudio',
      'userPreferencesChanged': false,
    };
    await tester.pumpWidget(const SizedBox());
    await app.flush();
    ads.dispose();
    container.dispose();
  });
}
