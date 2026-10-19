import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zon/core/theme/app_theme.dart';
import 'package:zon/data/app_state.dart';
import 'package:zon/presentation/common/toast_overlay.dart';

void main() {
  testWidgets('toasts disappear on their own', (tester) async {
    final state = AppState(downloads: const [], history: const []);
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: ToastOverlay(state: state, child: const SizedBox.expand()),
      ),
    );

    state.showToast('Paused movie.mkv');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Paused movie.mkv'), findsOneWidget);

    // 2.4 s on screen, then the fade-out.
    await tester.pump(const Duration(milliseconds: 2400));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Paused movie.mkv'), findsNothing);

    // A follow-up toast still shows and clears.
    state.showToast('Downloads resumed');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Downloads resumed'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2400));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Downloads resumed'), findsNothing);
  });
}
