import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui/memory_card.dart';

import '../core/controller.dart';
import '../core/models.dart';
import '../ui/vector_art.dart';
import '../ui/listen.dart';

class EngineContext {
  final Activity activity;
  final AppController app;
  final VoidCallback complete;
  final VoidCallback? onMistake, onProgress;
  final Map<String, dynamic>? resume;
  final void Function(Map<String, dynamic>) save;
  EngineContext({
    required this.activity,
    required this.app,
    required this.complete,
    this.onMistake,
    this.onProgress,
    required this.resume,
    required this.save,
  });
  String get contentLanguage => app.activityLanguage(activity);
  String get contentFont =>
      contentLanguage == 'ar' ? 'NotoSansArabic' : 'Nunito';
  TextDirection get contentDirection =>
      contentLanguage == 'ar' ? TextDirection.rtl : TextDirection.ltr;
  Map<String, dynamic> get config => activity.config(contentLanguage);
  Widget art(String id, {double size = 130}) => SizedBox(
    width: size,
    height: size,
    child: ArtThumbnail(scene: sceneFor(app.catalog.art, id)),
  );
}

class QuizActivity extends StatefulWidget {
  final EngineContext engine;
  const QuizActivity({super.key, required this.engine});
  @override
  State<QuizActivity> createState() => _QuizActivityState();
}

class _QuizActivityState extends State<QuizActivity> {
  String? selected;
  bool hint = false, finished = false;
  Timer? reset;
  EngineContext get e => widget.engine;
  void choose(String value) {
    if (finished) return;
    setState(() => selected = value);
    if (value == e.config['correct']) {
      finished = true;
      e.complete();
    } else {
      e.onMistake?.call();
      unawaited(e.app.audio.play(e.app.language, 'again.mp3'));
      reset?.cancel();
      reset = Timer(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => selected = null);
      });
    }
  }

  @override
  void dispose() {
    reset?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = e.config;
    final options = (cfg['options'] as List).cast<Map>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (cfg['question'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                localized(cfg['question'], e.app.language),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          if (cfg['clock'] != null)
            SizedBox(
              width: 240,
              height: 240,
              child: CustomPaint(
                painter: ClockPainter(
                  cfg['clock']['hour'],
                  cfg['clock']['minute'],
                ),
              ),
            ),
          if (cfg['count'] != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 550),
              child: Wrap(
                spacing: 5,
                runSpacing: 5,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < cfg['count']; i++)
                    e.art(
                      cfg['subject'],
                      size: cfg['count'] > 20
                          ? 44
                          : cfg['count'] > 10
                          ? 57
                          : 77,
                    ),
                ],
              ),
            ),
          if (cfg['subject'] != null &&
              cfg['count'] == null &&
              cfg['spokenOnly'] != true)
            e.art(cfg['subject'], size: 210),
          if (cfg['spokenOnly'] == true)
            Padding(
              padding: const EdgeInsets.all(24),
              child: FilledButton.tonalIcon(
                onPressed: () => listenToActivity(context, e.app, e.activity),
                icon: Icon(
                  e.app.sound ? Icons.volume_up : Icons.volume_off,
                  size: 38,
                ),
                label: Text(e.app.t('listen')),
              ),
            ),
          if (cfg['display'] != null &&
              cfg['display'].toString().isNotEmpty &&
              cfg['spokenOnly'] != true)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Directionality(
                textDirection: cfg['direction'] == 'rtl'
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                child: Text(
                  cfg['display'],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: cfg['display'].toString().length < 8 ? 48 : 32,
                    fontWeight: FontWeight.w900,
                    fontFamily: e.contentFont,
                  ),
                ),
              ),
            ),
          if (cfg['spokenOnly'] == true &&
              !e.app.sound &&
              cfg['visualCue'] != null)
            Text(
              localized(cfg['visualCue'], e.contentLanguage),
              textDirection: e.activity.languageLesson
                  ? e.contentDirection
                  : TextDirection.ltr,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                fontFamily: e.contentFont,
              ),
            ),
          if (cfg['pictures'] != null)
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                for (final id in cfg['pictures']) e.art(id, size: 62),
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    '?',
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final option in options)
                      SizedBox(
                        width: (constraints.maxWidth - 12) / 2,
                        child: Semantics(
                          button: true,
                          label: localized(option['label'], e.contentLanguage),
                          child: Material(
                            color: selected == option['value']
                                ? (selected == cfg['correct']
                                      ? const Color(0xFFD5EBD7)
                                      : const Color(0xFFF9D9D3))
                                : (hint && option['value'] == cfg['correct']
                                      ? const Color(0xFFFFE6A0)
                                      : Colors.white),
                            borderRadius: BorderRadius.circular(22),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(22),
                              key: ValueKey('option-${option['value']}'),
                              onTap: () => choose(option['value']),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    if (option['art'] != null)
                                      e.art(option['art'], size: 85),
                                    if (option['color'] != null)
                                      Container(
                                        width: 66,
                                        height: 66,
                                        decoration: BoxDecoration(
                                          color: hexColor(option['color']),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    Text(
                                      localized(
                                        option['label'],
                                        e.contentLanguage,
                                      ),
                                      textDirection: e.activity.languageLesson
                                          ? e.contentDirection
                                          : null,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: option['art'] != null
                                            ? 18
                                            : 27,
                                        fontWeight: FontWeight.w800,
                                        fontFamily: e.contentFont,
                                      ),
                                    ),
                                    if (selected == option['value'])
                                      Text(
                                        selected == cfg['correct']
                                            ? e.app.t('great')
                                            : e.app.t('again'),
                                        textAlign: TextAlign.center,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => setState(() => hint = true),
            icon: const Icon(Icons.lightbulb_outline),
            label: Text(e.app.t('hint')),
          ),
        ],
      ),
    );
  }
}

class ClockPainter extends CustomPainter {
  final int hour, minute;
  ClockPainter(this.hour, this.minute);
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width * .45;
    canvas.drawCircle(center, r, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = const Color(0xFF74BEC6)
        ..strokeWidth = 10
        ..style = PaintingStyle.stroke,
    );
    for (var i = 1; i <= 12; i++) {
      final a = i * math.pi / 6;
      final p = center + Offset(math.sin(a), -math.cos(a)) * (r * .79);
      final t = TextPainter(
        text: TextSpan(
          text: '$i',
          style: const TextStyle(
            color: Color(0xFF344850),
            fontFamily: 'Nunito',
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      t.paint(canvas, p - Offset(t.width / 2, t.height / 2));
    }
    void hand(double angle, double length, double width, Color color) {
      canvas.drawLine(
        center,
        center + Offset(math.sin(angle), -math.cos(angle)) * length,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    hand(
      (hour % 12 + minute / 60) * math.pi / 6,
      r * .49,
      9,
      const Color(0xFF344850),
    );
    hand(minute * math.pi / 30, r * .69, 6, const Color(0xFFF17C6E));
    canvas.drawCircle(center, 8, Paint()..color = const Color(0xFFF3C65F));
  }

  @override
  bool shouldRepaint(ClockPainter old) =>
      old.hour != hour || old.minute != minute;
}

class WordActivity extends StatefulWidget {
  final EngineContext engine;
  const WordActivity({super.key, required this.engine});
  @override
  State<WordActivity> createState() => _WordActivityState();
}

class _WordActivityState extends State<WordActivity> {
  int index = 0;
  bool finished = false;
  String? wrong;
  Timer? reset;
  EngineContext get e => widget.engine;
  List<String> get letters => e.config['word'].toString().characters.toList();
  @override
  void initState() {
    super.initState();
    index = (e.resume?['index'] ?? 0).clamp(0, letters.length - 1);
  }

  void choose(String letter) {
    if (finished) return;
    if (letter == letters[index]) {
      setState(() => index++);
      e.onProgress?.call();
      e.save({'index': index});
      if (index == letters.length) {
        finished = true;
        e.complete();
      }
    } else {
      e.onMistake?.call();
      setState(() => wrong = letter);
      reset?.cancel();
      reset = Timer(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => wrong = null);
      });
    }
  }

  @override
  void dispose() {
    reset?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final choices = letters.toSet().toList();
    choices.sort();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          e.art(e.config['subject'], size: 220),
          const SizedBox(height: 20),
          Text(
            letters.take(index).join(),
            key: const ValueKey('word-progress'),
            textDirection: e.contentDirection,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              fontFamily: e.contentFont,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            textDirection: e.contentDirection,
            spacing: 7,
            runSpacing: 7,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < letters.length; i++)
                Container(
                  width: 43,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i < index
                        ? const Color(0xFF83BA88)
                        : const Color(0xFFE0DCD3),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              for (final char in choices)
                FilledButton.tonal(
                  key: ValueKey('letter-$char'),
                  onPressed: () => choose(char),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(68, 68),
                    backgroundColor: wrong == char
                        ? const Color(0xFFF9D9D3)
                        : null,
                  ),
                  child: char == ' '
                      ? const Icon(Icons.space_bar)
                      : Text(
                          char,
                          textDirection: e.contentDirection,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            fontFamily: e.contentFont,
                          ),
                        ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: finished ? null : () => choose(letters[index]),
            icon: const Icon(Icons.lightbulb_outline),
            label: Text(e.app.t('hint')),
          ),
        ],
      ),
    );
  }
}

class SortingActivity extends StatefulWidget {
  final EngineContext engine;
  const SortingActivity({super.key, required this.engine});
  @override
  State<SortingActivity> createState() => _SortingActivityState();
}

class _SortingActivityState extends State<SortingActivity> {
  Set<String> sorted = {};
  String? selected;
  bool finished = false;
  EngineContext get e => widget.engine;
  @override
  void initState() {
    super.initState();
    sorted = (e.resume?['sorted'] as List? ?? []).cast<String>().toSet();
  }

  void place(String id, String group) {
    if (finished) return;
    final items = (e.config['items'] as List).cast<Map>();
    final item = items.firstWhere((j) => j['value'] == id);
    if (item['target'] == group) {
      setState(() {
        sorted.add(id);
        selected = null;
      });
      e.onProgress?.call();
      e.save({'sorted': sorted.toList()});
      if (sorted.length == items.length) {
        finished = true;
        e.complete();
      }
    } else {
      e.onMistake?.call();
      unawaited(e.app.audio.play(e.app.language, 'again.mp3'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = (e.config['items'] as List).cast<Map>();
    final groups = (e.config['groups'] as List).cast<Map>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              for (final item in items)
                if (!sorted.contains(item['value']))
                  Draggable<String>(
                    data: item['value'],
                    feedback: Material(
                      color: Colors.transparent,
                      child: e.art(item['art'], size: 105),
                    ),
                    childWhenDragging: Opacity(
                      opacity: .2,
                      child: e.art(item['art'], size: 105),
                    ),
                    child: InkWell(
                      key: ValueKey('sort-item-${item['value']}'),
                      onTap: () => setState(() => selected = item['value']),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 105,
                        height: 105,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: selected == item['value']
                              ? const Color(0xFFFFE6A0)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: e.art(item['art'], size: 90),
                      ),
                    ),
                  ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final group in groups)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: DragTarget<String>(
                      onAcceptWithDetails: (d) => place(d.data, group['value']),
                      builder: (context, candidates, rejected) => InkWell(
                        key: ValueKey('sort-group-${group['value']}'),
                        onTap: selected == null
                            ? null
                            : () => place(selected!, group['value']),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 190),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: candidates.isNotEmpty
                                ? const Color(0xFFFFE6A0)
                                : const Color(0xFFE4EEDE),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFF83BA88),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              if (group['color'] != null)
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: hexColor(group['color']),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              Text(
                                localized(group['label'], e.app.language),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                alignment: WrapAlignment.center,
                                children: [
                                  for (final item in items)
                                    if (sorted.contains(item['value']) &&
                                        item['target'] == group['value'])
                                      e.art(item['art'], size: 52),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '${sorted.length} / ${items.length}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class MemoryActivity extends StatefulWidget {
  final EngineContext engine;
  const MemoryActivity({super.key, required this.engine});
  @override
  State<MemoryActivity> createState() => _MemoryActivityState();
}

class _MemoryActivityState extends State<MemoryActivity> {
  late List<String> deck;
  Set<int> matched = {};
  List<int> open = [];
  bool busy = false, finished = false;
  Timer? timer;
  EngineContext get e => widget.engine;
  @override
  void initState() {
    super.initState();
    final pairs = (e.config['pairs'] as List).cast<String>();
    deck = [...pairs, ...pairs];
    deck.shuffle(math.Random(e.config['layout']));
    matched = (e.resume?['matched'] as List? ?? []).cast<int>().toSet();
  }

  void flip(int i) {
    if (busy || finished || matched.contains(i) || open.contains(i)) return;
    setState(() => open.add(i));
    if (open.length == 2) {
      busy = true;
      timer = Timer(
        Duration(milliseconds: deck[open[0]] == deck[open[1]] ? 650 : 1300),
        () {
          if (!mounted) return;
          final pair = deck[open[0]] == deck[open[1]];
          setState(() {
            if (pair) matched.addAll(open);
            open.clear();
            busy = !pair;
          });
          if (!pair) {
            final reduced =
                MediaQuery.disableAnimationsOf(context) ||
                MediaQuery.accessibleNavigationOf(context);
            timer = Timer(
              reduced ? Duration.zero : MemoryCard.turnDuration,
              () {
                if (mounted) setState(() => busy = false);
              },
            );
          }
          if (pair) {
            e.onProgress?.call();
            e.save({'matched': matched.toList()});
          } else {
            e.onMistake?.call();
          }
          if (matched.length == deck.length) {
            finished = true;
            e.complete();
          }
        },
      );
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final cols = deck.length > 12 ? 4 : 3;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              '${matched.length ~/ 2} / ${deck.length ~/ 2}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: deck.length,
                itemBuilder: (context, i) {
                  final show = open.contains(i) || matched.contains(i);
                  return Semantics(
                    label: '${e.app.t('step')} ${i + 1}',
                    button: true,
                    enabled: !busy && !finished && !show,
                    onTap: !busy && !finished && !show ? () => flip(i) : null,
                    child: MemoryCard(
                      key: ValueKey('memory-$i'),
                      faceUp: show,
                      matched: matched.contains(i),
                      face: e.art(deck[i]),
                      onTap: !busy && !finished && !show ? () => flip(i) : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

class JigsawActivity extends StatefulWidget {
  final EngineContext engine;
  const JigsawActivity({super.key, required this.engine});
  @override
  State<JigsawActivity> createState() => _JigsawActivityState();
}

class _JigsawActivityState extends State<JigsawActivity> {
  late List<int> order;
  int? selected;
  bool preview = false, finished = false;
  EngineContext get e => widget.engine;
  int get n => e.config['size'];
  late int artRevision;
  @override
  void initState() {
    super.initState();
    artRevision = e.resume == null ? 3 : e.resume!['artRevision'] ?? 2;
    order =
        (e.resume?['order'] as List?)?.cast<int>() ??
        List.generate(n * n, (i) => (i + 1) % (n * n));
  }

  void swap(int a, int b) {
    if (finished || a == b) return;
    setState(() {
      final old = order[a];
      order[a] = order[b];
      order[b] = old;
      selected = null;
    });
    e.onProgress?.call();
    e.save({'order': order, 'artRevision': artRevision});
    if (List.generate(order.length, (i) => i).every((i) => order[i] == i)) {
      finished = true;
      e.complete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scene = sceneFor(
      e.app.catalog.artForRevision(artRevision),
      artRevision < 3
          ? e.config['legacyScene'] ?? e.config['scene']
          : e.config['scene'],
    )!;
    Widget tile(int i) => DragTarget<int>(
      onAcceptWithDetails: (d) => swap(d.data, i),
      builder: (context, candidates, rejected) => Draggable<int>(
        data: i,
        feedback: SizedBox(
          width: 100,
          height: 100,
          child: CustomPaint(painter: TilePainter(scene, n, order[i])),
        ),
        childWhenDragging: const ColoredBox(color: Color(0xFFE5EEF0)),
        child: Semantics(
          label: '${e.app.t('step')} ${order[i] + 1}',
          button: true,
          child: InkWell(
            key: ValueKey('jigsaw-$i'),
            onTap: () {
              if (selected == null) {
                setState(() => selected = i);
              } else {
                swap(selected!, i);
              }
            },
            child: AnimatedContainer(
              duration: e.app.reducedMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 140),
              decoration: BoxDecoration(
                border: Border.all(
                  color: selected == i || candidates.isNotEmpty
                      ? const Color(0xFFF2B544)
                      : const Color(0xFFF9F8F4),
                  width: selected == i || candidates.isNotEmpty ? 3 : 1,
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CustomPaint(
                  painter: TilePainter(scene, n, order[i]),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final extent = math.min(
          650.0,
          math.min(
            constraints.maxWidth - 32,
            math.max(n * 54.0 + 24, constraints.maxHeight - 128),
          ),
        );
        final placed = order.indexed.where((p) => p.$1 == p.$2).length;
        return SizedBox(
          width: constraints.maxWidth,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                SizedBox(
                  width: extent,
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 76,
                          height: 76,
                          child: ArtThumbnail(scene: scene),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton.icon(
                        onPressed: () => setState(() => preview = !preview),
                        icon: Icon(
                          preview
                              ? Icons.grid_view_rounded
                              : Icons.image_outlined,
                        ),
                        label: Text(e.app.t('hint')),
                      ),
                      const Spacer(),
                      Text(
                        '$placed / ${order.length}',
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: extent,
                  height: extent,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFDCE8E7),
                      width: 2,
                    ),
                  ),
                  child: preview
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: ArtThumbnail(scene: scene),
                        )
                      : Directionality(
                          textDirection: TextDirection.ltr,
                          child: GridView.builder(
                            padding: EdgeInsets.zero,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: n,
                                  mainAxisSpacing: 4,
                                  crossAxisSpacing: 4,
                                ),
                            itemCount: order.length,
                            itemBuilder: (context, i) => tile(i),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class TilePainter extends CustomPainter {
  final VectorScene scene;
  final int n, index;
  TilePainter(this.scene, this.n, this.index);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(-(index % n) * size.width, -(index ~/ n) * size.height);
    VectorPainter(scene: scene)
        .drawScene(canvas, Size(size.width * n, size.height * n));
    canvas.restore();
  }

  @override
  bool shouldRepaint(TilePainter old) =>
      old.index != index || old.n != n || old.scene != scene;
}

class MusicActivity extends StatefulWidget {
  final EngineContext engine;
  const MusicActivity({super.key, required this.engine});
  @override
  State<MusicActivity> createState() => _MusicActivityState();
}

class _MusicActivityState extends State<MusicActivity> {
  int at = 0;
  bool playing = false, finished = false;
  int? lit;
  EngineContext get e => widget.engine;
  List<int> get notes => (e.config['notes'] as List).cast<int>();
  @override
  void initState() {
    super.initState();
    at = (e.resume?['at'] ?? 0).clamp(0, notes.length - 1);
  }

  Future<void> play() async {
    if (playing || finished) return;
    setState(() => playing = true);
    for (final note in notes) {
      if (!mounted || !e.app.audio.active) {
        if (mounted) setState(() => playing = false);
        return;
      }
      setState(() => lit = note);
      await e.app.audio.note(note);
      await Future<void>.delayed(Duration(milliseconds: e.config['tempo']));
    }
    if (mounted) {
      setState(() {
        lit = null;
        playing = false;
      });
    }
  }

  void tap(int note) {
    if (playing || finished) return;
    unawaited(e.app.audio.note(note));
    if (note == notes[at]) {
      setState(() => at++);
      e.onProgress?.call();
      e.save({'at': at});
      if (at == notes.length) {
        finished = true;
        e.complete();
      }
    } else {
      setState(() => at = 0);
      e.onMistake?.call();
      e.save({'at': 0});
    }
  }

  @override
  Widget build(BuildContext context) {
    final names = e.app.language == 'ar'
        ? ['دو', 'ري', 'مي', 'فا', 'صول', 'لا', 'سي', 'دو']
        : ['Do', 'Re', 'Mi', 'Fa', 'Sol', 'La', 'Si', 'Do'];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          e.art('piano', size: 180),
          FilledButton.icon(
            onPressed: playing
                ? null
                : () => listenWithFeedback(context, e.app, play),
            icon: const Icon(Icons.play_circle_outline),
            label: Text(e.app.t('listenAgain')),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < notes.length; i++)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: i < at
                        ? const Color(0xFF83BA88)
                        : const Color(0xFFE0DCD3),
                    shape: BoxShape.circle,
                  ),
                  child: i < at
                      ? const Icon(Icons.check, color: Colors.white, size: 21)
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 28),
          Directionality(
            textDirection: TextDirection.ltr,
            child: LayoutBuilder(
              builder: (context, c) {
                final width = (c.maxWidth - 24) / 4;
                return Wrap(
                  spacing: 8,
                  runSpacing: 12,
                  children: [
                    for (var i = 0; i < 8; i++)
                      SizedBox(
                        width: width,
                        height: 104,
                        child: FilledButton.tonal(
                          key: ValueKey('note-$i'),
                          onPressed: () => tap(i),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            backgroundColor: lit == i
                                ? const Color(0xFFFFE6A0)
                                : [
                                    const Color(0xFFF9D9D3),
                                    const Color(0xFFFFE6A0),
                                    const Color(0xFFE4EEDE),
                                    const Color(0xFFD6EDF0),
                                  ][i % 4],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.music_note, size: 29),
                              Text(
                                names[i],
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 6,
            children: [
              for (final n in notes)
                Text(
                  names[n],
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
