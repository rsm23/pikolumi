import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/controller.dart';
import '../core/models.dart';
import '../services/ads.dart';
import '../activities/canvas_activity.dart';
import '../activities/learning.dart';
import '../activities/tracing_maze.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  final Activity activity;
  final AdsService ads;
  const ActivityScreen({super.key, required this.activity, required this.ads});
  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  late AppController controller;
  bool ready = false, finishing = false;
  Map<String, dynamic>? resume;
  @override
  void initState() {
    super.initState();
    controller = ref.read(appProvider);
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
    }
    unawaited(app.audio.play(app.language, widget.activity.audio));
  }

  @override
  void dispose() {
    widget.ads.leaveActivity();
    unawaited(controller.audio.stop());
    super.dispose();
  }

  Future<void> complete() async {
    if (finishing) return;
    setState(() => finishing = true);
    final app = ref.read(appProvider);
    await app.flush();
    await app.complete(widget.activity);
    await app.clearResume(widget.activity.id);
    await widget.ads.activityCompleted();
    if (!mounted) return;
    unawaited(app.audio.play(app.language, 'great.mp3'));
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 160,
                child: Image.asset(
                  'assets/art/piko.png',
                  excludeFromSemantics: true,
                ),
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
      save: (value) => unawaited(app.saveResume(a.id, value)),
    );
    final child = !ready
        ? const Center(child: CircularProgressIndicator())
        : switch (a.engine) {
            'canvas' => CanvasActivity(
              activity: a,
              app: app,
              onComplete: complete,
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
      canPop: !finishing,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          unawaited(app.flush());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            a.title(app.language),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              tooltip: app.t('listen'),
              onPressed: () =>
                  app.audio.play(app.language, a.cue(app.language) ?? a.audio),
              icon: const Icon(Icons.volume_up_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Text(
                  a.instructions(app.language),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: AbsorbPointer(absorbing: finishing, child: child),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
