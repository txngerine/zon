import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zon/app.dart';
import 'package:zon/core/theme/app_theme.dart';
import 'package:zon/core/widgets/mono_button.dart';
import 'package:zon/data/app_state.dart';
import 'package:zon/data/mock_data.dart';
import 'package:zon/presentation/dialogs/add_download_dialog.dart';

void main() {
  const sizes = <Size>[
    Size(320, 568),
    Size(390, 844),
    Size(768, 1024),
    Size(900, 640),
    Size(1100, 800),
    Size(1360, 900),
    Size(1600, 1000),
    Size(1920, 1080),
  ];

  void use(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  AppState makeState() {
    final state = AppState(
      downloads: MockData.downloads(),
      history: MockData.history(),
    );
    addTearDown(state.dispose);
    return state;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  for (final size in sizes) {
    final name = '${size.width.round()}x${size.height.round()}';

    testWidgets('shell fits at $name', (tester) async {
      use(tester, size);
      await tester.pumpWidget(ZonApp(state: makeState()));
      await tester.pump(const Duration(milliseconds: 1600));
      expect(tester.takeException(), isNull);
      await settle(tester);
    });

    testWidgets('add dialog fits at $name', (tester) async {
      use(tester, size);
      final state = makeState();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: MonoButton(
                  label: 'open',
                  onTap: () => unawaited(
                    AddDownloadDialog.show(
                      context,
                      state: state,
                      mode: AddDownloadMode.media,
                      initialUrl: 'https://youtu.be/dQw4w9WgXcQ',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('open'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(Dialog), findsOneWidget);
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
