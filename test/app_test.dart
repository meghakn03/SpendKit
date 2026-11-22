import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spendkit/src/app.dart';
import 'package:spendkit/src/core.dart';

import 'fakes.dart';

void main() {
  testWidgets('verify card changes and lock the workspace', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 860);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesProvider.overrideWithValue(MemoryPreferences()),
          bankApiProvider.overrideWithValue(FakeBankApi()),
        ],
        child: const SpendKitApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign in to your workspace'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), demoCode);
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(find.text('Business overview'), findsOneWidget);
    await tester.tap(find.text('Card'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Freeze card'));
    await tester.pumpAndSettle();
    expect(find.text('Verify access'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '0000');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the correct access code.'), findsOneWidget);
    await tester.tap(find.text('Freeze card'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), demoCode);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Unfreeze card'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Edit spending controls').hitTestable(),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit spending controls'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '250.99');
    await tester.tap(find.text('Block ATM withdrawals'));
    await tester.tap(find.text('Continue to verification'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), demoCode);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Per-transaction limit · £250.99'), findsOneWidget);
    expect(find.text('ATM withdrawals · Blocked'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Lock workspace'));
    await tester.tap(find.text('Lock workspace'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to your workspace'), findsOneWidget);
  });
}
