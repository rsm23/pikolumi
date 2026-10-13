import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/controller.dart';
import '../core/models.dart';
import '../services/ads.dart';
import 'activity_screen.dart';
import 'parent_area.dart';
import 'piko_mascot.dart';
import 'vector_art.dart';

const avatars = ['🐦', '🐱', '🐰', '🦊', '🐢', '🐼', '🦁', '🐸'];
const sectionMotifs = {
  'coloring': 'butterfly',
  'drawing': 'pencil',
  'tracing': 'pencil',
  'letters': 'book',
  'words': 'bird',
  'counting': 'apple',
  'math': 'rocket',
  'shapes': 'ball',
  'sorting': 'kite',
  'memory': 'cat',
  'jigsaw': 'train',
  'patterns': 'flower',
  'mazes': 'turtle',
  'nature': 'leaf',
  'everyday': 'clock',
  'music': 'piano',
};
IconData sectionIcon(String id) => switch (id) {
  'coloring' => Icons.palette_outlined,
  'drawing' => Icons.draw_outlined,
  'tracing' => Icons.gesture,
  'letters' => Icons.abc,
  'words' => Icons.menu_book,
  'counting' => Icons.format_list_numbered,
  'math' => Icons.calculate_outlined,
  'shapes' => Icons.category_outlined,
  'sorting' => Icons.sort,
  'memory' => Icons.style_outlined,
  'jigsaw' => Icons.extension_outlined,
  'patterns' => Icons.auto_awesome,
  'mazes' => Icons.route,
  'nature' => Icons.eco_outlined,
  'everyday' => Icons.schedule,
  'music' => Icons.music_note,
  _ => Icons.star_outline,
};
Activity blankActivity(AppController app) => Activity({
  'id': 'drawing-free',
  'section': 'drawing',
  'engine': 'canvas',
  'stage': 0,
  'title': app.catalog.strings['blank'],
  'instructions': app.catalog.strings['blank'],
  'audio': 'drawing.mp3',
  'config': {'mode': 'drawing'},
});
Future<void> openActivity(
  BuildContext context,
  AppController app,
  AdsService ads,
  Activity activity,
) => Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => ActivityScreen(activity: activity, ads: ads),
  ),
);

class LibraryHome extends ConsumerStatefulWidget {
  final AdsService ads;
  const LibraryHome({super.key, required this.ads});
  @override
  ConsumerState<LibraryHome> createState() => _LibraryHomeState();
}

class _LibraryHomeState extends ConsumerState<LibraryHome> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pikolumi',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        actions: [
          TextButton(
            onPressed: () => showModalBottomSheet(
              context: context,
              builder: (context) => SafeArea(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        app.t('profile'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    for (final (i, p) in app.profiles.indexed)
                      ListTile(
                        leading: Text(
                          avatars[p.avatar],
                          style: const TextStyle(fontSize: 30),
                        ),
                        title: Text('${app.t('explorer')} ${i + 1}'),
                        trailing: p.id == app.active.id
                            ? const Icon(Icons.check_circle)
                            : null,
                        onTap: () async {
                          Navigator.pop(context);
                          await app.selectProfile(p);
                        },
                      ),
                  ],
                ),
              ),
            ),
            child: Text(
              avatars[app.active.avatar],
              style: const TextStyle(fontSize: 28),
            ),
          ),
          IconButton(
            tooltip: app.t('parents'),
            onPressed: () async {
              if (await parentGate(context, app) && context.mounted) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ParentArea(ads: widget.ads),
                  ),
                );
              }
            },
            icon: const Icon(Icons.lock_outline),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: switch (tab) {
                0 => _worlds(app),
                1 => GalleryView(app: app, ads: widget.ads),
                _ => _stickers(app),
              },
            ),
            if (tab == 0) LibraryBanner(ads: widget.ads, label: app.t('ad')),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore),
            label: app.t('library'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.brush_outlined),
            selectedIcon: const Icon(Icons.brush),
            label: app.t('gallery'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.auto_awesome_outlined),
            selectedIcon: const Icon(Icons.auto_awesome),
            label: app.t('stickers'),
          ),
        ],
      ),
    );
  }

  Widget _worlds(AppController app) => CustomScrollView(
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        sliver: SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFFD6EDF0),
              borderRadius: BorderRadius.circular(32),
            ),
            child: LayoutBuilder(
              builder: (context, c) => Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.t('hello'),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF344850),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          app.t('tagline'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          '16 ${app.t('worldCount')} · 2,400 ${app.t('activities')}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.offline_bolt_outlined, size: 19),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                app.t('offline'),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PikoMascot(
                    key: const ValueKey('library-piko'),
                    size: c.maxWidth < 350 ? 100 : 150,
                    semanticLabel: app.t('pikoPlay'),
                    invitations: [
                      for (final key in [
                        'pikoInviteColor',
                        'pikoInviteMemory',
                        'pikoInvitePuzzle',
                        'pikoInviteNumbers',
                        'pikoInviteDraw',
                      ])
                        app.t(key),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
        sliver: SliverToBoxAdapter(
          child: FilledButton.tonalIcon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    SectionLibrary(ads: widget.ads, recommended: true),
              ),
            ),
            icon: const Icon(Icons.auto_awesome),
            label: Text(app.t('recommended')),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  app.t('worlds'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: app.t('favorites'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SectionLibrary(ads: widget.ads),
                  ),
                ),
                icon: const Icon(Icons.favorite_outline),
              ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.all(20),
        sliver: SliverLayoutBuilder(
          builder: (context, c) {
            final cols = c.crossAxisExtent > 1050
                ? 4
                : c.crossAxisExtent > 660
                ? 3
                : 2;
            return SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                mainAxisExtent: 215,
              ),
              itemCount: app.catalog.sections.length,
              itemBuilder: (context, i) {
                final s = app.catalog.sections[i];
                return Material(
                  color: Color(s.color),
                  borderRadius: BorderRadius.circular(25),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(25),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SectionLibrary(section: s, ads: widget.ads),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Center(
                              child: SizedBox(
                                width: 100,
                                height: 100,
                                child: ArtThumbnail(
                                  scene: sceneFor(
                                    app.catalog.art,
                                    sectionMotifs[s.id],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            s.name(app.language),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: app.language == 'ar' ? 17 : 19,
                              color: const Color(0xFF344850),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${s.count} ${app.t('activities')}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF344850),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  );
  Widget _stickers(AppController app) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        Text(
          app.t('stickers'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        Text(
          '${app.completed} ${app.t('completed')}',
          style: const TextStyle(fontSize: 20),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            for (final (i, id) in sectionMotifs.values.indexed)
              Container(
                width: 110,
                height: 125,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: Opacity(
                        opacity: app.earnedCompletions > i * 5 ? 1 : .18,
                        child: ArtThumbnail(
                          scene: sceneFor(app.catalog.art, id),
                        ),
                      ),
                    ),
                    Text(
                      app.earnedCompletions > i * 5 ? '★' : '${i * 5 + 1}',
                      style: const TextStyle(
                        fontSize: 20,
                        color: Color(0xFFBA8C2C),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

class SectionLibrary extends ConsumerStatefulWidget {
  final Section? section;
  final bool recommended;
  final AdsService ads;
  const SectionLibrary({
    super.key,
    this.section,
    this.recommended = false,
    required this.ads,
  });
  @override
  ConsumerState<SectionLibrary> createState() => _SectionLibraryState();
}

class _SectionLibraryState extends ConsumerState<SectionLibrary> {
  int? band;
  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final s = widget.section;
    final all = s == null
        ? app.catalog.activities
              .where(
                (a) => widget.recommended
                    ? a.stage == app.active.stage
                    : app.favorites.contains(a.id),
              )
              .toList()
        : app.catalog.bySection[s.id]!;
    final list = all.where((a) => band == null || a.stage == band).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          s?.name(app.language) ??
              app.t(widget.recommended ? 'recommended' : 'favorites'),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text(app.t('all')),
                    selected: band == null,
                    onSelected: (_) => setState(() => band = null),
                  ),
                  const SizedBox(width: 8),
                  for (var i = 0; i < 5; i++)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(
                        label: Text(app.t('stage$i')),
                        selected: band == i,
                        onSelected: (_) => setState(() => band = i),
                      ),
                    ),
                ],
              ),
            ),
            if (s?.id == 'drawing')
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FilledButton.tonalIcon(
                  onPressed: () => openActivity(
                    context,
                    app,
                    widget.ads,
                    blankActivity(app),
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(app.t('blank')),
                ),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) => GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: c.maxWidth > 1000
                        ? 5
                        : c.maxWidth > 650
                        ? 4
                        : 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    mainAxisExtent: 224,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final a = list[i];
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(23),
                      child: InkWell(
                        onTap: () => openActivity(context, app, widget.ads, a),
                        borderRadius: BorderRadius.circular(23),
                        child: Column(
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Padding(
                                      padding: const EdgeInsets.all(22),
                                      child: a.preview == null
                                          ? Center(
                                              child: Icon(
                                                sectionIcon(a.section),
                                                size: 65,
                                                color: const Color(0xFF74BEC6),
                                              ),
                                            )
                                          : ArtThumbnail(
                                              scene: sceneFor(
                                                app.catalog.art,
                                                a.preview,
                                              ),
                                            ),
                                    ),
                                  ),
                                  PositionedDirectional(
                                    top: 1,
                                    end: 1,
                                    child: IconButton(
                                      tooltip: app.t('favorites'),
                                      onPressed: () => app.toggleFavorite(a.id),
                                      icon: Icon(
                                        app.favorites.contains(a.id)
                                            ? Icons.favorite
                                            : Icons.favorite_outline,
                                        color: const Color(0xFFC86878),
                                      ),
                                    ),
                                  ),
                                  if (app.isCompleted(a))
                                    const PositionedDirectional(
                                      top: 12,
                                      start: 12,
                                      child: Icon(
                                        Icons.check_circle,
                                        color: Color(0xFF6C9A69),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                              child: Column(
                                children: [
                                  Text(
                                    app.activityTitle(a),
                                    textDirection: a.languageLesson
                                        ? (app.learningLanguage == 'ar'
                                              ? TextDirection.rtl
                                              : TextDirection.ltr)
                                        : null,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: a.languageLesson
                                          ? (app.learningLanguage == 'ar'
                                                ? 'NotoSansArabic'
                                                : 'Nunito')
                                          : null,
                                    ),
                                  ),
                                  Text(
                                    '#${a.id.split('-').last} · ${app.t('stage${a.stage}')}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF667582),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            LibraryBanner(ads: widget.ads, label: app.t('ad')),
          ],
        ),
      ),
    );
  }
}

class GalleryView extends StatelessWidget {
  final AppController app;
  final AdsService ads;
  final bool exporting;
  const GalleryView({
    super.key,
    required this.app,
    required this.ads,
    this.exporting = false,
  });
  @override
  Widget build(BuildContext context) {
    final ids = app.gallery.keys.toList().reversed.toList();
    if (ids.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Text(
            app.t('emptyGallery'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, c) => GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: c.maxWidth > 700 ? 4 : 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: .85,
        ),
        itemCount: ids.length,
        itemBuilder: (context, i) {
          final id = ids[i];
          final a = app.catalog.byId[id] ?? blankActivity(app);
          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(23),
            child: InkWell(
              borderRadius: BorderRadius.circular(23),
              onTap: () => exporting
                  ? exportPicture(context, app, id)
                  : openActivity(context, app, ads, a),
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: FutureBuilder<Map<String, dynamic>?>(
                        future: app.artwork(id),
                        builder: (context, s) => CustomPaint(
                          painter: VectorPainter(
                            scene: sceneFor(
                              app.catalog.artForRevision(
                                s.data?['artRevision'] ??
                                    app.gallery[id]['artRevision'] ??
                                    2,
                              ),
                              app.gallery[id]['scene'],
                            ),
                            outlineOnly: true,
                            drawing: s.data,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      app.activityTitle(a),
                      textDirection: a.languageLesson
                          ? (app.learningLanguage == 'ar'
                                ? TextDirection.rtl
                                : TextDirection.ltr)
                          : null,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontFamily: a.languageLesson
                            ? (app.learningLanguage == 'ar'
                                  ? 'NotoSansArabic'
                                  : 'Nunito')
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class LibraryBanner extends StatefulWidget {
  final AdsService ads;
  final String label;
  const LibraryBanner({super.key, required this.ads, required this.label});
  @override
  State<LibraryBanner> createState() => _LibraryBannerState();
}

class _LibraryBannerState extends State<LibraryBanner> {
  BannerAd? banner;
  AdSize? renderedSize;
  bool loaded = false;
  int width = 0;
  Orientation? orientation;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    widget.ads.addListener(changed);
  }

  void changed() {
    if (!widget.ads.ready) {
      generation++;
      banner?.dispose();
      banner = null;
      loaded = false;
      renderedSize = null;
      width = 0;
      orientation = null;
    }
    if (mounted) setState(() {});
  }

  Future<void> load(int w, Orientation direction) async {
    if (!widget.ads.ready || !mounted) return;
    final g = ++generation;
    banner?.dispose();
    setState(() {
      width = w;
      orientation = direction;
      banner = null;
      loaded = false;
      renderedSize = null;
    });
    // Keep the library footer compact; the large format reserves video space.
    // ignore: deprecated_member_use
    final size = await AdSize.getAnchoredAdaptiveBannerAdSize(direction, w);
    if (!mounted || !widget.ads.ready || g != generation || size == null) {
      return;
    }
    final ad = BannerAd(
      size: size,
      adUnitId: widget.ads.bannerId,
      request: const AdRequest(nonPersonalizedAds: true),
      listener: BannerAdListener(
        onAdLoaded: (ad) async {
          if (!mounted || !widget.ads.ready || g != generation) {
            ad.dispose();
            return;
          }
          AdSize? actualSize;
          try {
            actualSize = await (ad as BannerAd).getPlatformAdSize();
          } catch (_) {
            actualSize = null;
          }
          if (!mounted || !widget.ads.ready || g != generation) return;
          final fitted =
              actualSize != null &&
                  actualSize.width > 0 &&
                  actualSize.width <= w &&
                  actualSize.height > 0
              ? actualSize
              : size;
          setState(() {
            renderedSize = fitted;
            loaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted && g == generation) {
            setState(() {
              loaded = false;
              renderedSize = null;
            });
          }
        },
      ),
    );
    banner = ad;
    await ad.load();
  }

  @override
  void dispose() {
    generation++;
    widget.ads.removeListener(changed);
    banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.ads.ready ||
        widget.ads.presenting ||
        widget.ads.activityDepth > 0 ||
        !(ModalRoute.of(context)?.isCurrent ?? true)) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth.floor();
        final direction = MediaQuery.orientationOf(context);
        if (w != width || direction != orientation) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(load(w, direction));
          });
        }
        if (!loaded || banner == null || renderedSize == null) {
          return const SizedBox.shrink();
        }
        return Container(
          key: const ValueKey('library-banner'),
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFDDD8D0))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF667582)),
              ),
              const SizedBox(height: 4),
              SizedBox(
                key: const ValueKey('library-banner-slot'),
                width: renderedSize!.width.toDouble(),
                height: renderedSize!.height.toDouble(),
                child: AdWidget(key: ObjectKey(banner), ad: banner!),
              ),
            ],
          ),
        );
      },
    );
  }
}
