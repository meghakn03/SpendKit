import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spendkit_ui/spendkit_ui.dart';

void main() {
  testWidgets('button stays disabled while busy', (tester) async {
    var activations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpendButton(
            label: 'Save',
            busy: true,
            onPressed: () => activations++,
          ),
        ),
      ),
    );
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.bySemanticsLabel(RegExp('Working')), findsOneWidget);
    expect(activations, 0);
  });

  testWidgets('shared components fit a narrow screen at 200% text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SpendPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SpendHeading(
                        'Business spending',
                        subtitle: 'Review your team’s expenses.',
                      ),
                      const SpendField(label: 'Merchant'),
                      SpendButton(
                        label: 'Apply transaction filters',
                        icon: Icons.filter_list,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('panel and button appearance in ${brightness.name}', (
      tester,
    ) async {
      const fixture = Key('component-golden');
      await tester.pumpWidget(
        MaterialApp(
          theme: SpendTheme.build(brightness),
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: fixture,
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: SpendPanel(
                    padding: 0,
                    // Keep the fixture independent of font and locale.
                    child: Center(
                      child: SpendButton(label: '', onPressed: () {}),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(fixture),
        matchesGoldenFile('goldens/components_${brightness.name}.png'),
      );
    });
  }
}
