import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'piko_mascot.dart';

class CompletionEncouragement {
  static final keys = List<String>.unmodifiable([
    'pikoFinished',
    for (var i = 1; i < 100; i++) 'pikoFinished$i',
  ]);
  final PikoShuffleBag<String> _messages;

  CompletionEncouragement({math.Random? random})
    : _messages = PikoShuffleBag<String>(random: random);

  String nextKey() => _messages.next(keys);
}

/// Short, silent prompts use foreground time and never affect learning results.
class ActivityEncouragement extends ChangeNotifier {
  // Shared across activity routes so opening a new challenge keeps the sequence.
  static final completions = CompletionEncouragement();
  static const idleDelay = Duration(seconds: 45);
  static const displayTime = Duration(seconds: 10);
  static const cooldownTime = Duration(seconds: 90);
  static const helpKeys = ['pikoTakeTime', 'pikoTryStep', 'pikoTogether'];
  static const creativeKeys = ['pikoCreative', 'pikoTakeTime'];
  final bool creative;
  final messages = PikoShuffleBag<String>();
  Timer? _idle, _hide, _cooldown;
  bool _active = false, _finished = false, _cooling = false;
  int _misses = 0;
  String? messageKey;

  ActivityEncouragement({this.creative = false});

  void setActive(bool value) {
    if (_finished || value == _active) return;
    _active = value;
    _cancelTimers();
    _clearMessage();
    if (value) {
      if (_cooling) {
        _scheduleCooldown();
      } else {
        _scheduleIdle();
      }
    }
  }

  void interact() {
    if (!_active || _finished) return;
    _hide?.cancel();
    _clearMessage();
    _scheduleIdle();
  }

  void progress() {
    _misses = 0;
    interact();
  }

  void mistake() {
    if (!_active || _finished || creative) return;
    if (++_misses >= 3 && !_cooling) _show();
  }

  void _scheduleIdle() {
    _idle?.cancel();
    if (!_active || _finished || _cooling) return;
    _idle = Timer(idleDelay, _show);
  }

  void _show() {
    if (!_active || _finished || _cooling) return;
    _idle?.cancel();
    _misses = 0;
    _cooling = true;
    messageKey = messages.next(creative ? creativeKeys : helpKeys);
    notifyListeners();
    _hide = Timer(displayTime, _clearMessage);
    _scheduleCooldown();
  }

  void _scheduleCooldown() {
    _cooldown = Timer(cooldownTime, () {
      _cooling = false;
      _misses = 0;
      _scheduleIdle();
    });
  }

  void _clearMessage() {
    if (messageKey == null) return;
    messageKey = null;
    notifyListeners();
  }

  void finish() {
    _finished = true;
    _cancelTimers();
    _clearMessage();
  }

  void _cancelTimers() {
    _idle?.cancel();
    _hide?.cancel();
    _cooldown?.cancel();
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }
}
