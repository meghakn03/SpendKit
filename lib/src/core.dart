import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data.dart';

const demoCode = '2048';

abstract interface class Biometrics {
  Future<bool> authenticate(String reason);
}

class DeviceBiometrics implements Biometrics {
  final _auth = LocalAuthentication();

  @override
  Future<bool> authenticate(String reason) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return false;
    }
    try {
      if ((await _auth.getAvailableBiometrics()).isEmpty) return false;
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } on Exception {
      return false;
    }
  }
}

abstract interface class Preferences {
  Future<bool?> getBool(String key);
  Future<void> setBool(String key, bool value);
}

class LocalPreferences implements Preferences {
  final _delegate = SharedPreferencesAsync();

  @override
  Future<bool?> getBool(String key) => _delegate.getBool(key);

  @override
  Future<void> setBool(String key, bool value) => _delegate.setBool(key, value);
}

final preferencesProvider = Provider<Preferences>((ref) => LocalPreferences());
final biometricsProvider = Provider<Biometrics>((ref) => DeviceBiometrics());
final repositoryProvider = Provider<MockBankRepository>(
  (ref) => MockBankRepository(),
);
final transactionsProvider = FutureProvider<List<Transaction>>(
  (ref) => ref.watch(repositoryProvider).loadTransactions(),
);

final sessionProvider = ChangeNotifierProvider<SessionController>((ref) {
  return SessionController(
    ref.watch(preferencesProvider),
    ref.watch(biometricsProvider),
  );
});

class SessionController extends ChangeNotifier {
  SessionController(this._preferences, this._biometrics);

  final Preferences _preferences;
  final Biometrics _biometrics;
  bool signedIn = false;
  bool biometricEnabled = false;
  bool darkMode = false;
  bool highContrast = false;
  bool frozen = false;
  int _sessionVersion = 0;
  bool _cardPending = false;

  Future<void> load() async {
    final settings = await Future.wait([
      _preferences.getBool('biometrics'),
      _preferences.getBool('dark'),
      _preferences.getBool('contrast'),
      _preferences.getBool('frozen'),
    ]);
    biometricEnabled = settings[0] ?? false;
    darkMode = settings[1] ?? false;
    highContrast = settings[2] ?? false;
    frozen = settings[3] ?? false;
    notifyListeners();
  }

  bool signIn(String code) {
    if (code != demoCode) return false;
    signedIn = true;
    _sessionVersion++;
    notifyListeners();
    return true;
  }

  Future<bool> unlock() async {
    final version = _sessionVersion;
    if (!biometricEnabled ||
        !await _biometrics.authenticate('Unlock SpendKit') ||
        version != _sessionVersion ||
        !biometricEnabled) {
      return false;
    }
    return signIn(demoCode);
  }

  void lock() {
    _sessionVersion++;
    signedIn = false;
    notifyListeners();
  }

  Future<bool> setBiometrics(bool value) async {
    final version = _sessionVersion;
    if (!signedIn ||
        (value && !await _biometrics.authenticate('Enable biometric unlock')) ||
        version != _sessionVersion) {
      return false;
    }
    await _preferences.setBool('biometrics', value);
    biometricEnabled = value;
    notifyListeners();
    return true;
  }

  Future<void> setDark(bool value) async {
    await _preferences.setBool('dark', value);
    darkMode = value;
    notifyListeners();
  }

  Future<void> setContrast(bool value) async {
    await _preferences.setBool('contrast', value);
    highContrast = value;
    notifyListeners();
  }

  Future<bool> changeCard({
    required Future<String?> Function() requestCode,
  }) async {
    if (!signedIn || _cardPending) return false;
    _cardPending = true;
    final version = _sessionVersion;
    final next = !frozen;
    try {
      final approved =
          biometricEnabled &&
          await _biometrics.authenticate(
            next ? 'Freeze your card' : 'Unfreeze your card',
          );
      if (!signedIn || version != _sessionVersion) return false;
      if (!approved && await requestCode() != demoCode) return false;
      if (!signedIn || version != _sessionVersion) return false;
      await _preferences.setBool('frozen', next);
      frozen = next;
      notifyListeners();
      return true;
    } finally {
      _cardPending = false;
    }
  }
}
