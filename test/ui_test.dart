import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zon/app.dart';
import 'package:zon/core/widgets/filter_tabs.dart';
import 'package:zon/core/widgets/mono_button.dart';
import 'package:zon/data/app_state.dart';
import 'package:zon/domain/models/app_settings.dart';
import 'package:zon/domain/models/download.dart';
import 'package:zon/domain/models/ui_state.dart';
import 'package:zon/presentation/dashboard/download_card.dart';
import 'package:zon/presentation/details/details_panel.dart';
import 'package:zon/presentation/mobile/mobile_shell.dart';
import 'package:zon/presentation/shell/status_bar.dart';
import 'package:zon/presentation/sidebar/sidebar.dart';

void main() {
  Future<AppState> pumpZon(
    WidgetTester tester, {
    Size size = const Size(1600, 1000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = AppState();
    addTearDown(state.dispose);
    await tester.pumpWidget(ZonApp(state: state));
    await tester.pump(const Duration(milliseconds: 200));
    return state;
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  }

  group('desktop shell', () {
    testWidgets('renders the dashboard chrome', (tester) async {
      final state = await pumpZon(tester);

      expect(find.byType(Sidebar), findsOneWidget);
      expect(find.byType(StatusBar), findsOneWidget);
      expect(find.byType(DetailsPanel), findsOneWidget);
      expect(find.text('FAST  •  STABLE  •  POWERFUL'), findsOneWidget);
      expect(
        find.textContaining('Without', findRichText: true),
        findsOneWidget,
      );
      expect(find.byType(DownloadCard), findsWidgets);
      expect(find.text('SPEED LIMIT'), findsOneWidget);
      expect(state.selected, isNotNull);

      await finish(tester);
    });

    testWidgets('sidebar navigation switches sections', (tester) async {
      final state = await pumpZon(tester);

      final queuedTab = find.descendant(
        of: find.byType(FilterTabs<DownloadFilter>),
        matching: find.text('Queued'),
      );
      await tester.tap(queuedTab);
      await tester.pump(const Duration(milliseconds: 300));

      expect(state.section, AppSection.queued);
      expect(state.visibleDownloads.length, state.queuedCount);

      final historyItem = find.text('History');
      await tester.tap(historyItem.first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(state.section, AppSection.history);

      await finish(tester);
    });

    testWidgets('add download dialog creates a transfer', (tester) async {
      final state = await pumpZon(tester);
      final before = state.downloads.length;

      await tester.tap(find.widgetWithText(MonoButton, 'Add Download').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(Dialog), findsOneWidget);

      final urlField = find
          .descendant(of: find.byType(Dialog), matching: find.byType(TextField))
          .first;
      await tester.enterText(urlField, 'https://example.com/premium-pack.iso');
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.widgetWithText(MonoButton, 'Start Download'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(Dialog), findsNothing);
      expect(state.downloads.length, before + 1);
      expect(state.downloads.first.fileName, 'premium-pack.iso');

      await finish(tester);
    });

    testWidgets('pausing a download updates its state', (tester) async {
      final state = await pumpZon(tester);
      final activeBefore = state.activeCount;
      expect(activeBefore, greaterThan(0));

      final pauseButton = find.byTooltip('Pause').first;
      await tester.ensureVisible(pauseButton);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(pauseButton);
      await tester.pump(const Duration(milliseconds: 400));

      expect(state.activeCount, activeBefore - 1);
      expect(state.pausedCount, greaterThan(0));

      await finish(tester);
    });

    testWidgets('details panel shows the selected download', (tester) async {
      final state = await pumpZon(tester);
      final target = state.downloads.firstWhere(
        (item) => item.status == DownloadStatus.downloading,
      );

      state.select(target.id);
      await tester.pump(const Duration(milliseconds: 300));

      final panel = find.byType(DetailsPanel);
      expect(
        find.descendant(of: panel, matching: find.text(target.fileName)),
        findsWidgets,
      );
      expect(
        find.descendant(of: panel, matching: find.text('STATISTICS')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: panel, matching: find.text('ADVANCED')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: panel, matching: find.text('Connections')),
        findsOneWidget,
      );

      await finish(tester);
    });

    testWidgets('settings screen edits preferences', (tester) async {
      final state = await pumpZon(tester);
      state.setSection(AppSection.settings);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Maximum simultaneous downloads'), findsOneWidget);
      expect(find.text('Default connections per download'), findsOneWidget);
      expect(find.text('NOTIFICATIONS'), findsOneWidget);

      final lightTab = find.descendant(
        of: find.byType(FilterTabs<ThemePreference>),
        matching: find.text('Light'),
      );
      await tester.ensureVisible(lightTab);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(lightTab);
      await tester.pump(const Duration(milliseconds: 300));
      expect(state.settings.theme, ThemePreference.light);

      await finish(tester);
    });

    testWidgets('history is searchable', (tester) async {
      final state = await pumpZon(tester);
      state.setSection(AppSection.history);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('History'), findsWidgets);

      final search = find.byType(TextField).first;
      await tester.enterText(search, 'blender');
      await tester.pump(const Duration(milliseconds: 300));

      expect(state.historyQuery, 'blender');
      expect(state.visibleHistory, isNotEmpty);
      expect(
        state.visibleHistory.every(
          (entry) => entry.fileName.toLowerCase().contains('blender'),
        ),
        isTrue,
      );

      await finish(tester);
    });

    testWidgets('empty state appears when the library is empty', (
      tester,
    ) async {
      final state = await pumpZon(tester);
      for (final item in [...state.downloads]) {
        state.removeDownload(item.id);
      }
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('No downloads yet.'), findsOneWidget);
      expect(find.text('Your downloads will appear here.'), findsOneWidget);

      await finish(tester);
    });
  });

  group('mobile shell', () {
    testWidgets('renders single column layout with bottom navigation', (
      tester,
    ) async {
      final state = await pumpZon(tester, size: const Size(400, 860));

      expect(find.byType(MobileShell), findsOneWidget);
      expect(find.byType(Sidebar), findsNothing);
      expect(find.text('Home'), findsOneWidget);
      expect(
        find.textContaining('Without', findRichText: true),
        findsOneWidget,
      );
      expect(find.byType(DownloadCard), findsWidgets);

      await tester.tap(find.text('Settings'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(state.section, AppSection.settings);
      expect(find.text('Maximum simultaneous downloads'), findsOneWidget);

      await finish(tester);
    });
  });
}
