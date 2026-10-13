import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../services/store_interface.dart';
import '../services/audio.dart';
import 'models.dart';

final appProvider = ChangeNotifierProvider<AppController>(
  (ref) => throw StateError('AppController must be initialized'),
);

class AppController extends ChangeNotifier {
  final Catalog catalog;
  final RecordStore store;
  final AudioService audio;
  List<Explorer> profiles = [];
  late Explorer active;
  String language = 'en';
  bool sound = true, reducedMotion = false;
  String? pinSalt, pinHash;
  int gateFailures = 0, gateLockedUntil = 0;
  Map<String, dynamic> results = {}, gallery = {};
  Set<String> favorites = {};
  Future<void> _pending = Future.value();
  AppController({
    required this.catalog,
    required this.store,
    required this.audio,
  });
  String t(String key) => catalog.text(key, language);
  String get learningLanguage => active.learningLanguage ?? language;
  String activityLanguage(Activity activity) =>
      activity.languageLesson ? learningLanguage : language;
  String activityTitle(Activity activity) =>
      activity.title(activityLanguage(activity));
  String _stateKey(String id) {
    final activity = catalog.byId[id];
    return activity?.languageLesson == true ? '$id@$learningLanguage' : id;
  }

  bool isCompleted(Activity activity) =>
      results[_stateKey(activity.id)]?['completed'] == true;
  Future<void> initialize() async {
    final raw = await store.read('settings', 'app');
    if (raw != null) {
      final j = jsonDecode(raw);
      language = j['language'] ?? 'en';
      sound = j['sound'] ?? true;
      reducedMotion = j['reducedMotion'] ?? false;
      pinSalt = j['pinSalt'];
      pinHash = j['pinHash'];
      gateFailures = j['gateFailures'] ?? 0;
      gateLockedUntil = j['gateLockedUntil'] ?? 0;
      profiles = (j['profiles'] as List? ?? [])
          .map((p) => Explorer.fromJson(Map<String, dynamic>.from(p)))
          .toList();
    }
    if (profiles.isEmpty) {
      profiles = [const Explorer(id: 'explorer-1', avatar: 0, stage: 0)];
    }
    final selected = raw == null ? null : jsonDecode(raw)['active'];
    active = profiles.firstWhere(
      (p) => p.id == selected,
      orElse: () => profiles.first,
    );
    if (raw != null && jsonDecode(raw)['languageLearningSchema'] != 1) {
      await _migrateLanguageRecords(language);
    }
    audio.enabled = sound;
    await _loadProfile();
    await saveSettings();
  }

  Future<void> _migrateLanguageRecords(String previousLanguage) async {
    for (final profile in profiles) {
      for (final kind in ['results', 'resume']) {
        final namespace = '$kind:${profile.id}';
        for (final entry in (await store.list(namespace)).entries) {
          if (catalog.byId[entry.key]?.languageLesson != true) continue;
          final key = '${entry.key}@$previousLanguage';
          if (await store.read(namespace, key) == null) {
            await store.write(namespace, key, entry.value);
          }
          await store.remove(namespace, entry.key);
        }
      }
    }
  }

  Future<void> _loadProfile() async {
    results = {
      for (final e in (await store.list('results:${active.id}')).entries)
        e.key: jsonDecode(e.value),
    };
    gallery = {
      for (final e in (await store.list('gallery:${active.id}')).entries)
        e.key: jsonDecode(e.value),
    };
    favorites = (jsonDecode(
      await store.read('favorites', active.id) ?? '[]',
    ) as List).cast<String>().toSet();
  }

  Future<void> saveSettings() {
    final value = jsonEncode({
      'language': language,
      'languageLearningSchema': 1,
      'sound': sound,
      'reducedMotion': reducedMotion,
      'active': active.id,
      'profiles': profiles.map((p) => p.toJson()).toList(),
      'pinSalt': pinSalt,
      'pinHash': pinHash,
      'gateFailures': gateFailures,
      'gateLockedUntil': gateLockedUntil,
    });
    return store.write('settings', 'app', value);
  }

  Future<void> selectProfile(Explorer profile) async {
    await flush();
    await audio.stop();
    active = profiles.firstWhere((p) => p.id == profile.id);
    await _loadProfile();
    await saveSettings();
    notifyListeners();
  }

  Future<void> addProfile(int avatar, int stage) async {
    final id = 'explorer-${DateTime.now().microsecondsSinceEpoch}';
    final p = Explorer(id: id, avatar: avatar, stage: stage);
    profiles.add(p);
    await selectProfile(p);
  }

  Future<void> setStage(int stage) async {
    active = active.copyWith(stage: stage);
    profiles = profiles.map((p) => p.id == active.id ? active : p).toList();
    await saveSettings();
    notifyListeners();
  }

  Future<void> setLanguage(String value) async {
    await audio.stop();
    language = value;
    await saveSettings();
    notifyListeners();
  }

  Future<void> setLearningLanguage(String? value) async {
    if (value != null && !['en', 'fr', 'es', 'pt', 'ar'].contains(value)) {
      throw ArgumentError.value(
        value,
        'value',
        'Unsupported learning language',
      );
    }
    await flush();
    await audio.stop();
    active = active.withLearningLanguage(value);
    profiles = profiles.map((p) => p.id == active.id ? active : p).toList();
    await saveSettings();
    notifyListeners();
  }

  Future<void> setSound(bool value) async {
    sound = value;
    audio.enabled = value;
    if (!value) await audio.stop();
    await saveSettings();
    notifyListeners();
  }

  Future<void> setMotion(bool value) async {
    reducedMotion = value;
    await saveSettings();
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    favorites.contains(id) ? favorites.remove(id) : favorites.add(id);
    await store.write('favorites', active.id, jsonEncode(favorites.toList()));
    notifyListeners();
  }

  Future<void> complete(Activity activity, {int hints = 0}) async {
    final key = _stateKey(activity.id);
    final result = {
      'completed': true,
      'attempts': (results[key]?['attempts'] ?? 0) + 1,
      'hints': hints,
      'updated': DateTime.now().toUtc().toIso8601String(),
    };
    results[key] = result;
    await store.write('results:${active.id}', key, jsonEncode(result));
    notifyListeners();
  }

  Future<Map<String, dynamic>?> artwork(String id) async {
    await flush();
    final value = await store.read('artwork:${active.id}', id);
    return value == null ? null : Map<String, dynamic>.from(jsonDecode(value));
  }

  Future<void> saveArtwork(
    String id,
    Map<String, dynamic> drawing, {
    String? scene,
  }) {
    final profile = active.id;
    final payload = jsonEncode(drawing);
    final metadata = {
      'id': id,
      'scene': scene,
      'artRevision': drawing['artRevision'] ?? 2,
      'updated': DateTime.now().toUtc().toIso8601String(),
    };
    _pending = _pending.then((_) async {
      await store.write('artwork:$profile', id, payload);
      await store.write('gallery:$profile', id, jsonEncode(metadata));
      if (active.id == profile) {
        gallery[id] = metadata;
        notifyListeners();
      }
    });
    return _pending;
  }

  Future<void> saveResume(String id, Map<String, dynamic> state) {
    final namespace = 'resume:${active.id}';
    final key = _stateKey(id);
    final value = jsonEncode(state);
    _pending = _pending.then((_) => store.write(namespace, key, value));
    return _pending;
  }

  Future<Map<String, dynamic>?> resume(String id) async {
    final raw = await store.read('resume:${active.id}', _stateKey(id));
    return raw == null ? null : Map<String, dynamic>.from(jsonDecode(raw));
  }

  Future<void> clearResume(String id) async {
    await flush();
    await store.remove('resume:${active.id}', _stateKey(id));
  }

  Future<void> flush() => _pending;
  int get completed => catalog.activities.where(isCompleted).length;
  int get earnedCompletions => results.entries
      .where(
        (r) =>
            r.value['completed'] == true &&
            catalog.byId.containsKey(r.key.split('@').first),
      )
      .map((r) => r.key.split('@').first)
      .toSet()
      .length;
  int sectionCompleted(String section) =>
      catalog.bySection[section]!.where(isCompleted).length;
  bool get gateLocked =>
      DateTime.now().millisecondsSinceEpoch < gateLockedUntil;
  Future<void> recordGateFailure() async {
    gateFailures++;
    if (gateFailures >= 5) {
      gateLockedUntil = DateTime.now().millisecondsSinceEpoch + 60000;
      gateFailures = 0;
    }
    await saveSettings();
  }

  Future<void> clearGateFailures() async {
    gateFailures = 0;
    gateLockedUntil = 0;
    await saveSettings();
  }

  bool get hasPin => pinHash != null;
  String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();
  Future<void> setPin(String pin) async {
    final random = Random.secure();
    pinSalt = List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    pinHash = _hash(pin, pinSalt!);
    await saveSettings();
  }

  bool verifyPin(String pin) => hasPin && _hash(pin, pinSalt!) == pinHash;
  @override
  void dispose() {
    unawaited(audio.dispose());
    super.dispose();
  }
}
