import 'package:flutter/material.dart';

import '../core/controller.dart';
import '../core/models.dart';

Future<void> listenWithFeedback(
  BuildContext context,
  AppController app,
  Future<void> Function() playback,
) async {
  if (!app.sound || !app.audio.enabled) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(app.t('soundOffHelp'))));
    return;
  }
  await playback();
}

Future<void> listenToActivity(
  BuildContext context,
  AppController app,
  Activity activity,
) => listenWithFeedback(context, app, () => playActivityPrompt(app, activity));

Future<void> playActivityPrompt(AppController app, Activity activity) {
  final language = app.activityLanguage(activity);
  final traceCues = activity.engine == 'trace'
      ? activity.traceCues(language)
      : const <String>[];
  if (traceCues.isNotEmpty) {
    return app.audio.playSequence(language, traceCues);
  }
  final cue = activity.cue(language);
  return app.audio.play(
    cue == null ? app.language : language,
    cue ?? activity.audio,
  );
}
