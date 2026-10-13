import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/controller.dart';
import 'core/models.dart';
import 'services/audio.dart';
import 'services/ads.dart';
import 'services/store_native.dart'
    if (dart.library.js_interop) 'services/store_web.dart'
    as persistence;
import 'ui/library.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final catalog = await Catalog.load();
    final store = await persistence.openStore();
    final audio = AudioService();
    final app = AppController(catalog: catalog, store: store, audio: audio);
    await app.initialize();
    final ads = AdsService(store, audio);
    runApp(
      ProviderScope(
        overrides: [appProvider.overrideWith((ref) => app)],
        child: PikolumiApp(ads: ads),
      ),
    );
    unawaited(ads.initialize());
  } catch (error, stack) {
    debugPrint('Pikolumi initialization failed: $error\n$stack');
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Pikolumi could not open its local library. Please restart the app.',
            ),
          ),
        ),
      ),
    );
  }
}

class PikolumiApp extends ConsumerWidget {
  final AdsService ads;
  const PikolumiApp({super.key, required this.ads});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    final theme = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFFBF7EE),
      fontFamily: app.language == 'ar' ? 'NotoSansArabic' : 'Nunito',
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF27868F),
        surface: const Color(0xFFFBF7EE),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFBF7EE),
        foregroundColor: Color(0xFF344850),
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(56, 54),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide.none,
        padding: const EdgeInsets.all(9),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w900,
          color: Color(0xFF344850),
        ),
        titleLarge: TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.w800,
          color: Color(0xFF344850),
        ),
        bodyLarge: TextStyle(fontSize: 17, color: Color(0xFF344850)),
      ),
    );
    return MaterialApp(
      title: 'Pikolumi',
      debugShowCheckedModeBanner: false,
      theme: theme,
      locale: Locale(app.language),
      supportedLocales: const [
        Locale('en'),
        Locale('fr'),
        Locale('es'),
        Locale('pt', 'BR'),
        Locale('ar'),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations:
              app.reducedMotion || MediaQuery.of(context).disableAnimations,
        ),
        child: child!,
      ),
      home: LibraryHome(ads: ads),
    );
  }
}
