import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:spendkit/src/core.dart';

import 'fakes.dart';

void main() {
  late MemoryPreferences preferences;
  late FakeBiometrics biometrics;
  late SessionController session;
  late FakeBankApi api;

  setUp(() {
    preferences = MemoryPreferences();
    biometrics = FakeBiometrics();
    api = FakeBankApi();
    session = SessionController(preferences, biometrics, api);
  });

  tearDown(() => session.dispose());

  test('a card change requires authentication and persists', () async {
    expect(
      await session.changeCard(requestCode: () async => demoCode),
      isFalse,
    );
    expect(await session.signIn('0000'), isFalse);
    expect(await session.signIn(demoCode), isTrue);
    expect(await session.changeCard(requestCode: () async => null), isFalse);
    expect(session.frozen, isFalse);
    expect(await session.changeCard(requestCode: () async => demoCode), isTrue);
    expect(session.frozen, isTrue);

    final restored = SessionController(preferences, biometrics, api);
    addTearDown(restored.dispose);
    await restored.load();
    expect(restored.signedIn, isFalse);
    await restored.signIn(demoCode);
    expect(restored.frozen, isTrue);
  });

  test(
    'lock invalidates a pending verification and prevents overlap',
    () async {
      await session.signIn(demoCode);
      final code = Completer<String?>();
      final result = session.changeCard(requestCode: () => code.future);
      expect(
        await session.changeCard(requestCode: () async => demoCode),
        isFalse,
      );
      session.lock();
      code.complete(demoCode);
      expect(await result, isFalse);
      expect(session.frozen, isFalse);
    },
  );

  test('biometric unlock requires enrollment and device approval', () async {
    biometrics.approved = true;
    expect(await session.unlock(), isFalse);
    await session.signIn(demoCode);
    expect(await session.setBiometrics(true), isTrue);
    session.lock();
    biometrics.approved = false;
    expect(await session.unlock(), isFalse);
    biometrics.approved = true;
    expect(await session.unlock(), isTrue);
  });
}
