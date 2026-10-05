import 'package:flutter/material.dart';

import '../../core/theme/app_type.dart';
import '../../core/theme/zon_palette.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/mono_button.dart';
import '../../core/widgets/mono_dropdown.dart';
import '../../data/app_state.dart';
import '../../domain/models/app_settings.dart';

/// Persistent bottom status bar: aggregate counters, global controls, speed
/// limit and the live transfer rate.
class StatusBar extends StatelessWidget {
  const StatusBar({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: palette.backgroundElevated,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 900;

          return Row(
            children: [
              Expanded(
                child: _Counters(state: state, hidden: narrow),
              ),
              if (!narrow) ...[
                MonoButton(
                  label: 'Pause All',
                  icon: Icons.pause_rounded,
                  height: 30,
                  fontSize: 12,
                  hPadding: 12,
                  variant: MonoButtonVariant.ghost,
                  onTap: state.activeCount == 0 ? null : state.pauseAll,
                ),
                const SizedBox(width: 6),
                MonoButton(
                  label: 'Resume All',
                  icon: Icons.play_arrow_rounded,
                  height: 30,
                  fontSize: 12,
                  hPadding: 12,
                  variant: MonoButtonVariant.ghost,
                  onTap: state.pausedCount == 0 && state.failedCount == 0
                      ? null
                      : state.resumeAll,
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (state.queuePaused && !narrow) ...[
                        Container(
                          height: 22,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: palette.textPrimary.withValues(
                                alpha: 0.22,
                              ),
                            ),
                          ),
                          child: Text(
                            'QUEUE PAUSED',
                            style: AppType.eyebrow(
                              palette.textSecondary,
                              size: 8.5,
                              spacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                      ],
                      if (!narrow) ...[
                        Text(
                          'SPEED LIMIT',
                          style: AppType.eyebrow(palette.textMuted, size: 8.5),
                        ),
                        const SizedBox(width: 8),
                        MonoDropdown<String>(
                          value: state.settings.defaultSpeedLimit,
                          options: [
                            for (final limit in AppSettings.speedLimits)
                              MonoOption(limit, limit),
                          ],
                          onChanged: state.setSpeedLimit,
                          height: 28,
                        ),
                        const SizedBox(width: 14),
                        Container(width: 1, height: 18, color: palette.border),
                        const SizedBox(width: 14),
                      ],
                      Icon(
                        Icons.arrow_downward_rounded,
                        size: 14,
                        color: palette.textPrimary,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        formatSpeed(state.totalSpeed),
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFeatures: AppType.tabular,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Counters extends StatelessWidget {
  const _Counters({required this.state, required this.hidden});

  final AppState state;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    if (hidden) return const SizedBox.shrink();
    final palette = context.palette;

    Widget counter(String value, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppType.numeric(
              palette.textPrimary,
              size: 12.5,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 5),
          Text(label, style: AppType.body(palette.textMuted, size: 12.5)),
        ],
      );
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          counter(
            '${state.activeCount}',
            'active download${state.activeCount == 1 ? '' : 's'}',
          ),
          _Separator(color: palette.border),
          counter('${state.queuedCount}', 'queued'),
          _Separator(color: palette.border),
          counter('${state.completedCount}', 'completed'),
          if (state.pausedCount > 0) ...[
            _Separator(color: palette.border),
            counter('${state.pausedCount}', 'paused'),
          ],
        ],
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(width: 3, height: 3, color: color),
    );
  }
}
