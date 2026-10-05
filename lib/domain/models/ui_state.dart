import 'package:flutter/material.dart';

import 'download.dart';

/// Primary navigation destinations in the shell.
enum AppSection {
  all,
  active,
  queued,
  completed,
  failed,
  history,
  settings;

  String get label => switch (this) {
    AppSection.all => 'All Downloads',
    AppSection.active => 'Active',
    AppSection.queued => 'Queued',
    AppSection.completed => 'Completed',
    AppSection.failed => 'Failed',
    AppSection.history => 'History',
    AppSection.settings => 'Settings',
  };

  IconData get icon => switch (this) {
    AppSection.all => Icons.download_rounded,
    AppSection.active => Icons.downloading_rounded,
    AppSection.queued => Icons.schedule_rounded,
    AppSection.completed => Icons.check_rounded,
    AppSection.failed => Icons.error_outline_rounded,
    AppSection.history => Icons.history_rounded,
    AppSection.settings => Icons.tune_rounded,
  };

  /// The download filter implied by this section (null for special screens).
  DownloadFilter? get filter => switch (this) {
    AppSection.all => DownloadFilter.all,
    AppSection.active => DownloadFilter.active,
    AppSection.queued => DownloadFilter.queued,
    AppSection.completed => DownloadFilter.completed,
    AppSection.failed => DownloadFilter.failed,
    AppSection.history || AppSection.settings => null,
  };

  bool get isRoot => this == AppSection.history || this == AppSection.settings;
}

/// Filter tabs above the download list.
enum DownloadFilter {
  all,
  active,
  queued,
  completed,
  failed;

  String get label => switch (this) {
    DownloadFilter.all => 'All',
    DownloadFilter.active => 'Active',
    DownloadFilter.queued => 'Queued',
    DownloadFilter.completed => 'Completed',
    DownloadFilter.failed => 'Failed',
  };

  bool matches(DownloadStatus status) => switch (this) {
    DownloadFilter.all => true,
    DownloadFilter.active =>
      status == DownloadStatus.downloading ||
          status == DownloadStatus.verifying,
    DownloadFilter.queued => status == DownloadStatus.queued,
    DownloadFilter.completed => status == DownloadStatus.completed,
    DownloadFilter.failed =>
      status == DownloadStatus.failed || status == DownloadStatus.cancelled,
  };
}

enum SortOption {
  newest,
  oldest,
  name,
  size;

  String get label => switch (this) {
    SortOption.newest => 'Newest',
    SortOption.oldest => 'Oldest',
    SortOption.name => 'Name',
    SortOption.size => 'Size',
  };
}

enum ViewMode { list, compact }

/// History status filters.
enum HistoryFilter {
  all,
  completed,
  failed,
  cancelled;

  String get label => switch (this) {
    HistoryFilter.all => 'All',
    HistoryFilter.completed => 'Completed',
    HistoryFilter.failed => 'Failed',
    HistoryFilter.cancelled => 'Cancelled',
  };

  bool matches(DownloadStatus status) => switch (this) {
    HistoryFilter.all => true,
    HistoryFilter.completed => status == DownloadStatus.completed,
    HistoryFilter.failed => status == DownloadStatus.failed,
    HistoryFilter.cancelled => status == DownloadStatus.cancelled,
  };
}
