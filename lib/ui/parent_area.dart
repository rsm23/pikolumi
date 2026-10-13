import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/controller.dart';
import '../services/ads.dart';
import 'library.dart';
import 'vector_art.dart';

Future<bool> parentGate(
  BuildContext context,
  AppController app, {
  bool change = false,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ParentGate(app: app, change: change),
    ) ??
    false;

class ParentGate extends StatefulWidget {
  final AppController app;
  final bool change;
  const ParentGate({super.key, required this.app, this.change = false});
  @override
  State<ParentGate> createState() => _ParentGateState();
}

class _ParentGateState extends State<ParentGate> {
  final answer = TextEditingController(),
      pin = TextEditingController(),
      confirmation = TextEditingController();
  late final int a, b;
  bool adult = false;
  String? error;
  bool busy = false;
  AppController get app => widget.app;
  @override
  void initState() {
    super.initState();
    final rng = Random.secure();
    a = 23 + rng.nextInt(64);
    b = 13 + rng.nextInt(15);
    adult = widget.change;
  }

  String digits(String input) => input.split('').map((char) {
    const eastern = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    final a = eastern.indexOf(char), b = persian.indexOf(char);
    return a >= 0
        ? '$a'
        : b >= 0
        ? '$b'
        : char;
  }).join();
  Future<void> submit() async {
    if (busy) return;
    setState(() => busy = true);
    if (app.gateLocked) {
      setState(() {
        error = app.t('gateWait');
        busy = false;
      });
      return;
    }
    if (!app.hasPin && !adult) {
      if (int.tryParse(digits(answer.text)) == a * b) {
        setState(() {
          adult = true;
          error = null;
          busy = false;
        });
      } else {
        await app.recordGateFailure();
        if (mounted) {
          setState(() {
            error = app.t('gateWrong');
            busy = false;
          });
        }
      }
      return;
    }
    if (adult) {
      if (RegExp(r'^\d{6}$').hasMatch(digits(pin.text)) &&
          digits(pin.text) == digits(confirmation.text)) {
        await app.setPin(digits(pin.text));
        if (mounted) Navigator.pop(context, true);
      } else {
        setState(() {
          error = app.t('pinLength');
          busy = false;
        });
      }
      return;
    }
    if (app.verifyPin(digits(pin.text))) {
      await app.clearGateFailures();
      if (mounted) Navigator.pop(context, true);
    } else {
      await app.recordGateFailure();
      if (mounted) {
        setState(() {
          error = app.t('gateWrong');
          busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    answer.dispose();
    pin.dispose();
    confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(adult ? app.t('gateSetup') : app.t('gateTitle')),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(app.t('gateHelp')),
          const SizedBox(height: 18),
          if (!app.hasPin && !adult) ...[
            Text(app.t('gateChallenge')),
            const SizedBox(height: 8),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                '$a × $b = ?',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextField(
              controller: answer,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: app.t('answer')),
            ),
          ] else ...[
            TextField(
              controller: pin,
              obscureText: true,
              maxLength: 6,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: app.t('gatePin')),
            ),
            if (adult) ...[
              TextField(
                controller: confirmation,
                obscureText: true,
                maxLength: 6,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: app.t('gateConfirm')),
              ),
              Text(app.t('pinNote'), style: const TextStyle(fontSize: 12)),
            ],
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: Text(app.t('back')),
      ),
      FilledButton(
        onPressed: busy ? null : submit,
        child: Text(app.t('continue')),
      ),
    ],
  );
}

class ParentArea extends ConsumerStatefulWidget {
  final AdsService ads;
  const ParentArea({super.key, required this.ads});
  @override
  ConsumerState<ParentArea> createState() => _ParentAreaState();
}

class _ParentAreaState extends ConsumerState<ParentArea>
    with WidgetsBindingObserver {
  bool needsGate = false;
  AdsService get ads => widget.ads;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) needsGate = true;
    if (state == AppLifecycleState.resumed && needsGate && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    return Scaffold(
      appBar: AppBar(title: Text(app.t('parents'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              app.t('profile'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final (i, p) in app.profiles.indexed)
                  ChoiceChip(
                    label: Text(
                      '${avatars[p.avatar]} ${app.t('explorer')} ${i + 1}',
                    ),
                    selected: p.id == app.active.id,
                    onSelected: (_) => app.selectProfile(p),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add),
                  label: Text(app.t('newProfile')),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => NewProfile(app: app),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              app.t('difficulty'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (var i = 0; i < 5; i++)
              ListTile(
                title: Text(app.t('stage$i')),
                leading: Icon(
                  app.active.stage == i
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                onTap: () => app.setStage(i),
              ),
            const Divider(),
            Text(
              app.t('interfaceLanguage'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final language in const {
                  'en': 'English',
                  'fr': 'Français',
                  'es': 'Español',
                  'pt': 'Português (Brasil)',
                  'ar': 'العربية',
                }.entries)
                  ChoiceChip(
                    label: Text(language.value),
                    selected: app.language == language.key,
                    onSelected: (_) => app.setLanguage(language.key),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              app.t('learningLanguage'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(app.t('learningLanguageHelp')),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  key: const ValueKey('learning-language-follow'),
                  label: Text(app.t('followInterface')),
                  selected: app.active.learningLanguage == null,
                  onSelected: (_) => app.setLearningLanguage(null),
                ),
                for (final language in const {
                  'en': 'English',
                  'fr': 'Français',
                  'es': 'Español',
                  'pt': 'Português (Brasil)',
                  'ar': 'العربية',
                }.entries)
                  ChoiceChip(
                    key: ValueKey('learning-language-${language.key}'),
                    label: Text(language.value),
                    selected: app.active.learningLanguage == language.key,
                    onSelected: (_) => app.setLearningLanguage(language.key),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(app.t('sound')),
              value: app.sound,
              onChanged: (value) async {
                await app.setSound(value);
                await ads.synchronizeSound();
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(app.t('motion')),
              value: app.reducedMotion,
              onChanged: app.setMotion,
            ),
            const Divider(),
            Text(
              app.t('progress'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text('${app.completed} / 2,400 ${app.t('completed')}'),
            for (final section in app.catalog.sections)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${section.name(app.language)} · ${app.sectionCompleted(section.id)} / ${section.count}',
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: app.sectionCompleted(section.id) / section.count,
                      minHeight: 7,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ],
                ),
              ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.ios_share),
              title: Text(app.t('chooseExport')),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: Text(app.t('export'))),
                    body: GalleryView(app: app, ads: ads, exporting: true),
                  ),
                ),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_reset),
              title: Text(app.t('changePin')),
              onTap: () => parentGate(context, app, change: true),
            ),
            const Divider(),
            Text(
              app.t('privacy'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(app.t('localPrivacy'), style: const TextStyle(fontSize: 16)),
            ListenableBuilder(
              listenable: ads,
              builder: (context, _) => ads.needsPrivacyAction
                  ? ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: Text(app.t('privacyOptions')),
                      onTap: () => ads.privacyOptions(
                        canPresent: () =>
                            context.mounted &&
                            (ModalRoute.of(context)?.isCurrent ?? false),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            if (const String.fromEnvironment('SUPPORT_URL').isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.open_in_new),
                title: Text(app.t('support')),
                onTap: () => launchUrl(
                  Uri.parse(const String.fromEnvironment('SUPPORT_URL')),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.info_outline),
              title: Text(app.t('credits')),
              onTap: () async {
                final credits = await rootBundle.loadString(
                  'assets/content/CREDITS.txt',
                );
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: Text(app.t('credits'))),
                      body: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: SelectableText(credits),
                            ),
                          ),
                          SafeArea(
                            top: false,
                            child: TextButton(
                              onPressed: () => showLicensePage(
                                context: context,
                                applicationName: 'Pikolumi',
                                applicationVersion: '1.0.0',
                              ),
                              child: Text(
                                MaterialLocalizations.of(context)
                                    .licensesPageTitle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const Text(
              'Pikolumi · 1.0.0',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF667582)),
            ),
          ],
        ),
      ),
    );
  }
}

class NewProfile extends StatefulWidget {
  final AppController app;
  const NewProfile({super.key, required this.app});
  @override
  State<NewProfile> createState() => _NewProfileState();
}

class _NewProfileState extends State<NewProfile> {
  int avatar = 0, stage = 0;
  bool saving = false;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.app.t('newProfile')),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (i, label) in avatars.indexed)
                ChoiceChip(
                  label: Text(label, style: const TextStyle(fontSize: 30)),
                  selected: i == avatar,
                  onSelected: (_) => setState(() => avatar = i),
                ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: stage,
            isExpanded: true,
            items: [
              for (var i = 0; i < 5; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    widget.app.t('stage$i'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) => setState(() => stage = v ?? 0),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(widget.app.t('back')),
      ),
      FilledButton(
        onPressed: saving
            ? null
            : () async {
                setState(() => saving = true);
                await widget.app.addProfile(avatar, stage);
                if (context.mounted) Navigator.pop(context);
              },
        child: Text(widget.app.t('save')),
      ),
    ],
  );
}

Future<void> exportPicture(
  BuildContext context,
  AppController app,
  String id,
) async {
  final drawing = await app.artwork(id);
  if (drawing == null || !context.mounted) return;
  final image = await renderArtwork(
    sceneFor(
      app.catalog.artForRevision(drawing['artRevision'] ?? 2),
      app.gallery[id]['scene'],
    ),
    drawing,
  );
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (png == null || !context.mounted) return;
  final box = context.findRenderObject() as RenderBox?;
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(
          png.buffer.asUint8List(),
          mimeType: 'image/png',
          name: 'pikolumi-$id.png',
        ),
      ],
      fileNameOverrides: ['pikolumi-$id.png'],
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    ),
  );
}
