import 'package:flutter/material.dart';

class PikoSpeechBubble extends StatelessWidget {
  final String message;
  final bool pointUp;
  const PikoSpeechBubble({
    super.key,
    required this.message,
    this.pointUp = false,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: EdgeInsets.only(top: pointUp ? 10 : 0, bottom: pointUp ? 0 : 10),
      child: CustomPaint(
        foregroundPainter: _SpeechTail(
          pointUp: pointUp,
          rtl: Directionality.of(context) == TextDirection.rtl,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBF1),
            border: Border.all(color: const Color(0xFF4F7A7D)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF344850),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _SpeechTail extends CustomPainter {
  final bool pointUp, rtl;
  const _SpeechTail({required this.pointUp, required this.rtl});

  @override
  void paint(Canvas canvas, Size size) {
    // The upward tail sits below the activity header's Piko action.
    final x = pointUp
        ? (rtl ? 68.0 : size.width - 68).clamp(16.0, size.width - 16)
        : size.width / 2;
    final edge = pointUp ? 1.0 : size.height - 1;
    final tip = pointUp ? -7.0 : size.height + 7;
    final path = Path()
      ..moveTo(x - 7, edge)
      ..lineTo(x, tip)
      ..lineTo(x + 7, edge);
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFFBF1));
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF4F7A7D)
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_SpeechTail old) =>
      old.pointUp != pointUp || old.rtl != rtl;
}

/// Both states reserve the same space, so a message cannot move a touch target.
class ActivityGuidance extends StatelessWidget {
  final String instruction;
  final String? message;
  final List<String> possibleMessages;
  const ActivityGuidance({
    super.key,
    required this.instruction,
    required this.message,
    required this.possibleMessages,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final base = DefaultTextStyle.of(context).style;
        double measure(String text, TextStyle style, double width) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: base.merge(style)),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: width);
          final height = painter.height;
          painter.dispose();
          return height;
        }

        const instructionsStyle = TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
        );
        const speechStyle = TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
        );
        var height =
            measure(instruction, instructionsStyle, constraints.maxWidth - 16) +
            16;
        for (final text in possibleMessages) {
          final speechHeight =
              measure(text, speechStyle, constraints.maxWidth - 24) + 26;
          if (speechHeight > height) height = speechHeight;
        }
        return SizedBox(
          height: height,
          child: Align(
            alignment: Alignment.center,
            child: message == null
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      instruction,
                      textAlign: TextAlign.center,
                      style: instructionsStyle,
                    ),
                  )
                : SizedBox(
                    width: double.infinity,
                    child: PikoSpeechBubble(
                      key: const ValueKey('activity-encouragement'),
                      message: message!,
                      pointUp: true,
                    ),
                  ),
          ),
        );
      },
    ),
  );
}
