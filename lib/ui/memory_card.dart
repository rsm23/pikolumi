import 'dart:math' as math;

import 'package:flutter/material.dart';

class MemoryCard extends StatelessWidget {
  static const turnDuration = Duration(milliseconds: 420);
  final bool faceUp, matched;
  final Widget face;
  final VoidCallback? onTap;

  const MemoryCard({
    super.key,
    required this.faceUp,
    required this.matched,
    required this.face,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final target = faceUp ? math.pi : 0.0;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: target, end: target),
          duration: reduced ? Duration.zero : turnDuration,
          curve: Curves.easeInOutCubic,
          builder: (context, angle, _) {
            final front = angle >= math.pi / 2;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, .0018)
                ..rotateY(angle),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.rotationY(front ? math.pi : 0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x22344850),
                        blurRadius: 4 + math.sin(angle) * 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(
                          color: front
                              ? (matched
                                    ? const Color(0xFFD5EBD7)
                                    : Colors.white)
                              : const Color(0xFFAA9BDB),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: front
                                ? face
                                : const Icon(
                                    Icons.auto_awesome,
                                    color: Colors.white,
                                    size: 38,
                                  ),
                          ),
                        ),
                        IgnorePointer(
                          child: ColoredBox(
                            color: Colors.black.withValues(
                              alpha: math.sin(angle) * .12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
