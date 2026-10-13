import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/controller.dart';
import '../core/models.dart';
import '../services/ads.dart';
import '../activities/canvas_activity.dart';
import '../activities/learning.dart';
import '../activities/tracing_maze.dart';
import 'listen.dart';
import 'activity_encouragement.dart';
import 'piko_speech_bubble.dart';
import 'piko_mascot.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  final Activity activity;
  final AdsService ads;
  const ActivityScreen({super.key, required this.activity, required this.ads});
  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen>
    with WidgetsBindingObserver {
  late AppController controller;
  late final ActivityEncouragement encouragement;
  bool foreground = true, routeVisible = true;

  void updateEncouragement() {
    if (mounted) setState(() {});
  }

  void synchronizeEncouragement() => encouragement.setActive(
    ready && foreground && routeVisible && !finishing && !canvasFullScreen,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeVisible =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true);
    synchronizeEncouragement();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    synchronizeEncouragement();
  }

  bool ready = false, finishing = false;
  bool canvasFullScreen = false;
  final canvasKey = GlobalKey<CanvasActivityState>();
  Map<String, dynamic>? resume;
  @override
  void initState() {
    super.initState();
    controller = ref.read(appProvider);
    encouragement = ActivityEncouragement(
      creative: widget.activity.engine == 'canvas',
    )..addListener(updateEncouragement);
    foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    widget.ads.enterActivity();
    load();
  }

  Future<void> load() async {
    final app = ref.read(appProvider);
    final saved = await app.resume(widget.activity.id);
    if (mounted) {
      setState(() {
        resume = saved;
        ready = true;
      });
      synchronizeEncouragement();
    }
    unawaited(app.audio.play(app.language, widget.activity.audio));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    encouragement.removeListener(updateEncouragement);
    encouragement.dispose();
    widget.ads.leaveActivity();
    unawaited(controller.audio.stop());
    super.dispose();
  }

  Future<void> complete() async {
    if (finishing) return;
    encouragement.finish();
    setState(() => finishing = true);
    final app = ref.read(appProvider);
    await app.flush();
    await app.complete(widget.activity);
    await app.clearResume(widget.activity.id);
    await widget.ads.activityCompleted();
    if (!mounted) return;
    final completionKey = ActivityEncouragement.completions.nextKey();
    unawaited(app.audio.play(app.language, 'great.mp3'));
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          scrollable: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PikoSpeechBubble(
                key: const ValueKey('completion-encouragement'),
                message: app.t(completionKey),
              ),
              PikoMascot(
                size: 192,
                pose: PikoPose.celebrate,
                semanticLabel: app.t('pikoPlay'),
              ),
              Text(
                app.t('great'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              const Icon(Icons.stars, size: 64, color: Color(0xFFD8A647)),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(app.t('continue')),
            ),
          ],
        ),
      ),
    );
    await app.audio.stop();
    await widget.ads.afterCompletion();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final a = widget.activity;
    final engine = EngineContext(
      activity: a,
      app: app,
      complete: complete,
      resume: resume,
      onMistake: encouragement.mistake,
      onProgress: encouragement.progress,
      save: (value) {
        unawaited(app.saveResume(a.id, value));
      },
    );
    final child = !ready
        ? const Center(child: CircularProgressIndicator())
        : switch (a.engine) {
            'canvas' => CanvasActivity(
              key: canvasKey,
              activity: a,
              app: app,
              onComplete: complete,
              onFullScreenChanged: (value) {
                if (mounted) {
                  setState(() => canvasFullScreen = value);
                  synchronizeEncouragement();
                }
              },
            ),
            'quiz' => QuizActivity(engine: engine),
            'sequence' => WordActivity(engine: engine),
            'sort' => SortingActivity(engine: engine),
            'memory' => MemoryActivity(engine: engine),
            'jigsaw' => JigsawActivity(engine: engine),
            'music' => MusicActivity(engine: engine),
            'trace' => TraceActivity(engine: engine),
            'maze' => MazeActivity(engine: engine),
            _ => const SizedBox.shrink(),
          };
    return PopScope(
      canPop: !finishing && !canvasFullScreen,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          unawaited(app.flush());
        } else if (canvasFullScreen && !finishing) {
          canvasKey.currentState?.setFullScreen(false);
        }
      },
      child: Scaffold(
        appBar: canvasFullScreen
            ? null
            : AppBar(
                title: Text(
                  app.activityTitle(a),
                  textDirection: a.languageLesson
                      ? (app.learningLanguage == 'ar'
                            ? TextDirection.rtl
                            : TextDirection.ltr)
                      : null,
                  style: a.languageLesson
                      ? TextStyle(
                          fontFamily: app.learningLanguage == 'ar'
                              ? 'NotoSansArabic'
                              : 'Nunito',
                        )
                      : null,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  PikoMascot(
                    key: const ValueKey('activity-piko'),
                    semanticLabel: app.t('pikoPlay'),
                    pose: finishing ? PikoPose.celebrate : PikoPose.idle,
                  ),
                  IconButton(
                    tooltip: app.t('listen'),
                    onPressed: () => listenToActivity(context, app, a),
                    icon: Icon(
                      app.sound
                          ? Icons.volume_up_outlined
                          : Icons.volume_off_outlined,
                    ),
                  ),
                ],
              ),
        body: SafeArea(
          child: Column(
            children: [
              if (!canvasFullScreen)
                ActivityGuidance(
                  instruction: a.instructions(app.language),
                  message: encouragement.messageKey == null
                      ? null
                      : app.t(encouragement.messageKey!),
                  possibleMessages: [
                    for (final key
                        in encouragement.creative
                            ? ActivityEncouragement.creativeKeys
                            : ActivityEncouragement.helpKeys)
                      app.t(key),
                  ],
                ),
              Expanded(
                key: const ValueKey('activity-body'),
                child: Listener(
                  onPointerDown: (_) => encouragement.interact(),
                  onPointerMove: (_) {
                    if (a.engine == 'canvas' || a.engine == 'trace') {
                      encouragement.interact();
                    }
                  },
                  child: AbsorbPointer(absorbing: finishing, child: child),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
