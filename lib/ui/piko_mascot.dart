import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum PikoPose {
  idle,
  celebrate,
  wave,
  wink,
  nod,
  bow,
  wiggle,
  stretch,
  crayon,
  peek,
  flutter,
  hop;

  bool get reaction => index >= wave.index;
  int get frames => reaction ? 60 : 90;
  int get tile => this == celebrate ? 192 : 128;
  int get sheets => reaction ? 1 : 2;
}

/// Each gesture plays once before the shuffled collection starts again.
class PikoShuffleBag<T> {
  final math.Random random;
  List<T> _bag = [];
  T? _last;
  PikoShuffleBag({math.Random? random}) : random = random ?? math.Random();

  T next(List<T> choices) {
    assert(choices.isNotEmpty);
    if (_bag.isEmpty) {
      _bag = [...choices]..shuffle(random);
      if (_bag.length > 1 && _bag.last == _last) {
        final first = _bag.first;
        _bag[0] = _bag.last;
        _bag[_bag.length - 1] = first;
      }
    }
    return _last = _bag.removeLast();
  }
}

/// Offline Blender frames with silent tap reactions and library invitations.
class PikoMascot extends StatefulWidget {
  final double size;
  final PikoPose pose;
  final String semanticLabel;
  final List<String> invitations;
  const PikoMascot({
    super.key,
    this.size = 56,
    this.pose = PikoPose.idle,
    this.semanticLabel = 'Piko',
    this.invitations = const [],
  });

  @override
  State<PikoMascot> createState() => _PikoMascotState();
}

class _PikoMascotState extends State<PikoMascot>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..addStatusListener(_finished);
  late PikoPose pose = widget.pose;
  final reactions = PikoShuffleBag<PikoPose>();
  PikoShuffleBag<String> messages = PikoShuffleBag<String>();
  _PikoFrames? frames;
  List<ui.Image>? images;
  Timer? rest, invite, hideInvite;
  String? invitation;
  bool visible = false, resumed = true, reduced = false, accessible = false;
  bool reacting = false, hasInvited = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    resumed =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    motion.duration = Duration(milliseconds: pose.frames * 1000 ~/ 30);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduced = MediaQuery.disableAnimationsOf(context);
    accessible = MediaQuery.accessibleNavigationOf(context);
    visible = TickerMode.valuesOf(context).enabled;
    if (reduced) {
      _release();
      reacting = false;
      pose = widget.pose;
      motion.reset();
    } else if (frames == null) {
      _load();
    }
    _synchronize();
  }

  @override
  void didUpdateWidget(PikoMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.invitations, widget.invitations)) {
      _clearInvitations();
      messages = PikoShuffleBag<String>();
      hasInvited = false;
    }
    if (oldWidget.pose != widget.pose) {
      reacting = false;
      _select(widget.pose);
    }
    _synchronize();
  }

  void _select(PikoPose selected, {bool hold = false}) {
    _release();
    pose = selected;
    motion.duration = Duration(milliseconds: pose.frames * 1000 ~/ 30);
    motion.reset();
    if (hold) motion.value = 1;
    if (!reduced) _load();
  }

  void _load() {
    final entry = _PikoFrames.acquire(pose);
    frames = entry;
    entry.ready.then(
      (value) {
        if (!mounted || frames != entry) return;
        setState(() => images = value);
        _synchronize();
      },
      onError: (Object error, StackTrace stack) {
        // A static Piko remains available if an optional clip cannot decode.
        if (mounted && frames == entry) {
          setState(() {
            _release();
            reacting = false;
            pose = widget.pose;
          });
        }
      },
    );
  }

  void _react() {
    if (!visible || !resumed || reacting) return;
    _clearInvitations();
    if (reduced) {
      if (widget.invitations.isNotEmpty) _showInvitation();
      return;
    }
    setState(() {
      reacting = true;
      _select(
        reactions.next(PikoPose.values.where((p) => p.reaction).toList()),
      );
    });
  }

  void _finished(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (reacting) {
      setState(() {
        reacting = false;
        _select(widget.pose, hold: widget.pose == PikoPose.celebrate);
      });
    } else if (pose == PikoPose.idle) {
      _scheduleIdle();
    }
  }

  void _scheduleIdle() {
    rest?.cancel();
    if (!visible || !resumed || reduced || images == null) return;
    rest = Timer(const Duration(seconds: 4), () {
      rest = null;
      if (mounted && visible && resumed && !reduced) {
        motion.forward(from: 0);
      }
    });
  }

  void _scheduleInvitation() {
    if (invite != null ||
        invitation != null ||
        widget.invitations.isEmpty ||
        !visible ||
        !resumed ||
        reduced ||
        reacting ||
        widget.pose != PikoPose.idle) {
      return;
    }
    invite = Timer(
      hasInvited
          ? Duration(seconds: 45 + messages.random.nextInt(31))
          : const Duration(seconds: 24),
      () {
        invite = null;
        if (mounted && visible && resumed && !reacting && !reduced) {
          _showInvitation();
        }
      },
    );
  }

  void _showInvitation() {
    if (widget.invitations.isEmpty) return;
    setState(() {
      invitation = messages.next(widget.invitations);
      hasInvited = true;
    });
    hideInvite?.cancel();
    hideInvite = Timer(Duration(seconds: accessible ? 12 : 6), () {
      hideInvite = null;
      if (!mounted) return;
      setState(() => invitation = null);
      _scheduleInvitation();
    });
  }

  void _clearInvitations() {
    invite?.cancel();
    hideInvite?.cancel();
    invite = hideInvite = null;
    invitation = null;
  }

  void _synchronize() {
    if (!visible || !resumed || reduced || images == null) {
      rest?.cancel();
      rest = null;
      motion.stop();
      _clearInvitations();
    } else {
      if (!motion.isCompleted) {
        motion.forward();
      } else if (pose == PikoPose.idle && rest == null) {
        _scheduleIdle();
      }
      _scheduleInvitation();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => resumed = state == AppLifecycleState.resumed);
    _synchronize();
  }

  void _release() {
    rest?.cancel();
    rest = null;
    motion.stop();
    frames?.release();
    frames = null;
    images = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clearInvitations();
    _release();
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mascot = Semantics(
      label: widget.semanticLabel,
      button: true,
      onTap: _react,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _react();
              return null;
            },
          ),
        },
        child: GestureDetector(
          key: const ValueKey('piko-touch'),
          behavior: HitTestBehavior.opaque,
          onTap: _react,
          excludeFromSemantics: true,
          child: ExcludeSemantics(
            child: SizedBox.square(
              dimension: widget.size,
              child: images == null
                  ? Image.asset(
                      'assets/art/piko_3d/poster.webp',
                      gaplessPlayback: true,
                    )
                  : CustomPaint(
                      painter: PikoFramePainter(
                        images: images!,
                        motion: motion,
                        tile: pose.tile,
                        frameCount: pose.frames,
                        pose: pose,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
    if (widget.invitations.isEmpty) return mascot;
    final bubbleWidth = math.max(widget.size, 130.0);
    final bubbleStyle = DefaultTextStyle.of(context).style.merge(
      const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: Color(0xFF344850),
      ),
    );
    var bubbleHeight = 0.0;
    for (final message in widget.invitations) {
      final text = TextPainter(
        text: TextSpan(text: message, style: bubbleStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: bubbleWidth - 18);
      bubbleHeight = math.max(bubbleHeight, text.height + 26);
      text.dispose();
    }
    return SizedBox(
      width: bubbleWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: bubbleHeight,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedOpacity(
                opacity: invitation == null ? 0 : 1,
                duration: reduced
                    ? Duration.zero
                    : const Duration(milliseconds: 240),
                child: IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: CustomPaint(
                      foregroundPainter: const _PikoBubbleTail(),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBF1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF4F7A7D)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 8,
                          ),
                          child: Text(
                            invitation ?? '',
                            key: const ValueKey('piko-invitation'),
                            textAlign: TextAlign.center,
                            style: bubbleStyle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          mascot,
        ],
      ),
    );
  }
}

class _PikoBubbleTail extends CustomPainter {
  const _PikoBubbleTail();
  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final path = Path()
      ..moveTo(x - 7, size.height - 1)
      ..lineTo(x, size.height + 7)
      ..lineTo(x + 7, size.height - 1);
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFFBF1));
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF4F7A7D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_PikoBubbleTail oldDelegate) => false;
}

class _PikoFrames {
  static final cache = <PikoPose, _PikoFrames>{};
  final Future<List<ui.Image>> ready;
  int users = 0;
  _PikoFrames(PikoPose pose) : ready = _decode(pose);

  static _PikoFrames acquire(PikoPose pose) {
    final entry = cache.putIfAbsent(pose, () => _PikoFrames(pose));
    entry.users++;
    return entry;
  }

  static Future<List<ui.Image>> _decode(PikoPose pose) async {
    final images = <ui.Image>[];
    try {
      for (var i = 0; i < pose.sheets; i++) {
        final bytes = await rootBundle.load(
          'assets/art/piko_3d/${pose.name}_$i.webp',
        );
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        try {
          images.add((await codec.getNextFrame()).image);
        } finally {
          codec.dispose();
        }
      }
      return images;
    } catch (_) {
      for (final image in images) {
        image.dispose();
      }
      rethrow;
    }
  }

  void release() {
    if (--users != 0) return;
    cache.removeWhere((key, value) => identical(value, this));
    unawaited(
      ready.then((images) {
        for (final image in images) {
          image.dispose();
        }
      }, onError: (Object error, StackTrace stack) {}),
    );
  }
}

class PikoFramePainter extends CustomPainter {
  final List<ui.Image> images;
  final Animation<double> motion;
  final int tile, frameCount;
  final PikoPose pose;
  PikoFramePainter({
    required this.images,
    required this.motion,
    required this.tile,
    this.frameCount = 90,
    this.pose = PikoPose.idle,
  }) : super(repaint: motion);

  int get frame => (motion.value * frameCount).floor().clamp(0, frameCount - 1);

  @override
  void paint(Canvas canvas, Size size) {
    final local = frame % 64;
    canvas.drawImageRect(
      images[frame ~/ 64],
      Rect.fromLTWH(
        (local % 8) * tile.toDouble(),
        (local ~/ 8) * tile.toDouble(),
        tile.toDouble(),
        tile.toDouble(),
      ),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(PikoFramePainter oldDelegate) =>
      oldDelegate.images != images ||
      oldDelegate.motion != motion ||
      oldDelegate.tile != tile ||
      oldDelegate.frameCount != frameCount ||
      oldDelegate.pose != pose;
}
