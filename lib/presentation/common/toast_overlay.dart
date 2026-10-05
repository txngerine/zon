import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../core/theme/app_type.dart';
import '../../core/theme/zon_palette.dart';

/// Floating confirmation pill shown for engine actions.
class ToastOverlay extends StatefulWidget {
  const ToastOverlay({super.key, required this.state, required this.child});

  final AppState state;
  final Widget child;

  @override
  State<ToastOverlay> createState() => ToastOverlayState();
}

class ToastOverlayState extends State<ToastOverlay> {
  Timer? _timer;
  int _shownToken = 0;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_sync);
    _shownToken = widget.state.toastToken;
  }

  @override
  void didUpdateWidget(ToastOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      oldWidget.state.removeListener(_sync);
      widget.state.addListener(_sync);
    }
  }

  void _sync() {
    if (!mounted) return;
    final toast = widget.state.toast;
    if (toast == null) {
      _timer?.cancel();
      return;
    }
    if (widget.state.toastToken == _shownToken) return;
    _shownToken = widget.state.toastToken;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) widget.state.dismissToast();
    });
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.state.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final message = widget.state.toast;

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 22,
          left: 0,
          right: 0,
          child: IgnorePointer(
            // The overlay sits above the Scaffold, so give text a Material.
            child: Material(
              type: MaterialType.transparency,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -0.4),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: message == null
                      ? const SizedBox.shrink()
                      : Container(
                          key: ValueKey('${widget.state.toastToken}-$message'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: palette.surfaceHighest.withValues(
                              alpha: 0.96,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: palette.borderStrong),
                            boxShadow: [
                              BoxShadow(
                                color: palette.shadow.withValues(alpha: 0.5),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_downward_rounded,
                                size: 14,
                                color: palette.textPrimary,
                              ),
                              const SizedBox(width: 9),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 420,
                                ),
                                child: Text(
                                  message,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppType.body(
                                    palette.textPrimary,
                                    size: 12.5,
                                    weight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
