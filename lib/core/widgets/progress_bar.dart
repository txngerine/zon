import 'package:flutter/material.dart';

import '../theme/zon_palette.dart';

/// Thin, elegant progress bar with an animated highlight that sweeps across
/// the filled portion while a download is transferring.
class ZonProgressBar extends StatefulWidget {
  const ZonProgressBar({
    super.key,
    required this.value,
    this.height = 4,
    this.active = false,
    this.radius,
  });

  /// 0.0 – 1.0
  final double value;
  final double height;
  final bool active;
  final double? radius;

  @override
  State<ZonProgressBar> createState() => _ZonProgressBarState();
}

class _ZonProgressBarState extends State<ZonProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _shimmer.repeat();
  }

  @override
  void didUpdateWidget(ZonProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_shimmer.isAnimating) {
      _shimmer.repeat();
    } else if (!widget.active && _shimmer.isAnimating) {
      _shimmer.stop();
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = widget.radius ?? widget.height / 2;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: widget.value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Container(
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: palette.track,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value <= 0.001 ? 0.001 : value,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      palette.textPrimary.withValues(alpha: 0.7),
                      palette.textPrimary,
                    ],
                  ),
                ),
                child: widget.active
                    ? LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          if (width.isInfinite || width < 8) {
                            return const SizedBox.shrink();
                          }
                          return AnimatedBuilder(
                            animation: _shimmer,
                            builder: (context, child) {
                              final x = -130 + _shimmer.value * (width + 130);
                              return ClipRect(
                                child: Transform.translate(
                                  offset: Offset(x, 0),
                                  child: child,
                                ),
                              );
                            },
                            child: _ShimmerHighlight(height: widget.height),
                          );
                        },
                      )
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ShimmerHighlight extends StatelessWidget {
  const _ShimmerHighlight({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.5),
            Colors.white.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}
