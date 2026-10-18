import 'dart:convert';

import 'package:flutter/services.dart';

String localized(Object? value, String language) {
  if (value is Map) return (value[language] ?? value['en'] ?? '').toString();
  return value?.toString() ?? '';
}

class Section {
  final String id, icon;
  final int count, color;
  final Map<String, dynamic> names;
  Section(Map<String, dynamic> json)
    : id = json['id'],
      icon = json['icon'],
      count = json['count'],
      color = json['color'],
      names = Map<String, dynamic>.from(json['name']);
  String name(String language) => localized(names, language);
}

class Activity {
  final String id, section, engine, audio;
  final int stage;
  final String? preview;
  final Map<String, dynamic> data;
  Activity(this.data)
    : id = data['id'],
      section = data['section'],
      engine = data['engine'],
      stage = data['stage'],
      preview = data['preview'],
      audio = data['audio'];
  String title(String lang) => localized(data['title'], lang);
  bool get languageLesson =>
      section == 'letters' ||
      section == 'words' ||
      (section == 'tracing' && data['config']['locales'] != null);
  String instructions(String lang) => localized(data['instructions'], lang);
  Map<String, dynamic> config(String lang) {
    final source = Map<String, dynamic>.from(data['config']);
    final locales = source.remove('locales');
    if (locales is Map) {
      source.addAll(Map<String, dynamic>.from(locales[lang] ?? locales['en']));
    }
    return source;
  }

  String? cue(String lang) =>
      data['cue'] == null ? null : localized(data['cue'], lang);

  List<String> traceCues(String lang) {
    final files = config(lang)['traceCues'];
    if (files is List) return files.cast<String>();
    final file = cue(lang);
    return file == null || file.isEmpty ? const [] : [file];
  }
}

class Catalog {
  final int version;
  final List<Section> sections;
  final List<Activity> activities;
  final Map<String, dynamic> art, strings;
  final Map<String, dynamic> legacyArt;
  late final Map<String, Activity> byId = {for (final a in activities) a.id: a};
  late final Map<String, List<Activity>> bySection = {
    for (final section in sections)
      section.id: activities.where((a) => a.section == section.id).toList(),
  };
  Catalog({
    this.version = 3,
    required this.sections,
    required this.activities,
    required this.art,
    required this.strings,
    this.legacyArt = const {},
  });
  Map<String, dynamic> artForRevision(int revision) =>
      revision < 3 && legacyArt.isNotEmpty ? legacyArt : art;
  static Future<Catalog> load() async {
    final files = await Future.wait(
      [
        'catalog',
        'art',
        'strings',
        'art_legacy_v2',
      ].map((name) => rootBundle.loadString('assets/content/$name.json')),
    );
    final data = jsonDecode(files[0]) as Map<String, dynamic>;
    return Catalog(
      version: data['version'],
      sections: (data['sections'] as List)
          .map((j) => Section(Map<String, dynamic>.from(j)))
          .toList(),
      activities: (data['activities'] as List)
          .map((j) => Activity(Map<String, dynamic>.from(j)))
          .toList(),
      art: Map<String, dynamic>.from(jsonDecode(files[1])),
      strings: Map<String, dynamic>.from(jsonDecode(files[2])),
      legacyArt: Map<String, dynamic>.from(jsonDecode(files[3])),
    );
  }

  String text(String key, String lang) => localized(strings[key], lang);
}

class Explorer {
  final String id;
  final int avatar, stage;
  final String? learningLanguage;
  const Explorer({
    required this.id,
    required this.avatar,
    required this.stage,
    this.learningLanguage,
  });
  factory Explorer.fromJson(Map<String, dynamic> j) => Explorer(
    id: j['id'],
    avatar: j['avatar'],
    stage: j['stage'],
    learningLanguage: j['learningLanguage'],
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'avatar': avatar,
    'stage': stage,
    'learningLanguage': learningLanguage,
  };
  Explorer copyWith({int? stage}) => Explorer(
    id: id,
    avatar: avatar,
    stage: stage ?? this.stage,
    learningLanguage: learningLanguage,
  );
  Explorer withLearningLanguage(String? language) => Explorer(
    id: id,
    avatar: avatar,
    stage: stage,
    learningLanguage: language,
  );
}
