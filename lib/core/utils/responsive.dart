/// Layout breakpoints for the responsive shell.
enum ZonLayout {
  /// Sidebar + main content + persistent details panel.
  desktop,

  /// Icon rail sidebar + main content, details in a drawer.
  compact,

  /// Single column with bottom navigation.
  mobile,
}

class ZonBreakpoints {
  ZonBreakpoints._();

  /// Width at which the details panel becomes persistent (240 sidebar +
  /// 780 main + 340 details).
  static const double desktop = 1360;

  /// Width below which the sidebar collapses to an icon rail.
  static const double compact = 900;

  static ZonLayout layoutOf(double width) {
    if (width >= desktop) return ZonLayout.desktop;
    if (width >= compact) return ZonLayout.compact;
    return ZonLayout.mobile;
  }

  /// True when the hero heading should use the compact type scale.
  static bool isNarrow(double width) => width < 720;
}
