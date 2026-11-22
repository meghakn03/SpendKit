import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bank_api.dart';
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
final bankApiProvider = Provider<BankApi>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return HttpBankApi(client);
});

final transactionsProvider = FutureProvider<List<Transaction>>((ref) async {
  final token = ref.watch(sessionProvider.select((session) => session.token));
  if (token == null) return [];
  return ref.watch(bankApiProvider).transactions(token);
});

final sessionProvider = ChangeNotifierProvider<SessionController>((ref) {
  return SessionController(
    ref.watch(preferencesProvider),
    ref.watch(biometricsProvider),
    ref.watch(bankApiProvider),
  );
});

class SessionController extends ChangeNotifier {
  SessionController(this._preferences, this._biometrics, this._api);

  final Preferences _preferences;
  final Biometrics _biometrics;
  final BankApi _api;
  bool signedIn = false;
  String? _token;
  String? get token => signedIn ? _token : null;
  bool get canUnlock => biometricEnabled && _token != null;
  BankAccount? _account;
  BankAccount get account => _account!;
  bool get frozen => _account?.frozen ?? false;

  bool biometricEnabled = false;
  bool darkMode = false;
  bool highContrast = false;
  int _sessionVersion = 0;
  bool _cardPending = false;

  Future<void> load() async {
    final settings = await Future.wait([
      _preferences.getBool('biometrics'),
      _preferences.getBool('dark'),
      _preferences.getBool('contrast'),
    ]);
    biometricEnabled = settings[0] ?? false;
    darkMode = settings[1] ?? false;
    highContrast = settings[2] ?? false;
    notifyListeners();
  }

  Future<bool> signIn(String code) async {
    final version = ++_sessionVersion;
    try {
      final result = await _api.signIn(code);
      if (version != _sessionVersion) {
        unawaited(_revoke(result.token));
        return false;
      }
      final previous = _token;
      _token = result.token;
      _account = result.account;
      signedIn = true;
      if (previous != null) unawaited(_revoke(previous));
      notifyListeners();
      return true;
    } on BankApiException catch (error) {
      if (error.status == 401) return false;
      rethrow;
    }
  }

  Future<bool> unlock() async {
    final version = _sessionVersion;
    final token = _token;
    if (!biometricEnabled ||
        token == null ||
        !await _biometrics.authenticate('Unlock SpendKit') ||
        version != _sessionVersion ||
        !biometricEnabled) {
      return false;
    }
    try {
      final account = await _api.account(token);
      if (version != _sessionVersion || !biometricEnabled) return false;
      _account = account;
      signedIn = true;
      _sessionVersion++;
      notifyListeners();
      return true;
    } on BankApiException catch (error) {
      if (error.status != 401) rethrow;
      if (version == _sessionVersion) _token = null;
      return false;
    }
  }

  void lock() {
    _sessionVersion++;
    signedIn = false;
    final token = _token;
    if (!biometricEnabled && token != null) {
      _token = null;
      unawaited(_revoke(token));
    }
    notifyListeners();
  }

  Future<void> _revoke(String token) async {
    try {
      await _api.revoke(token);
    } on BankApiException {
      // The session also expires on the server if it cannot be revoked here.
    }
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
  }) {
    final next = !frozen;
    return _changeCard(requestCode, (token, code) => _api.setCard(token, code, frozen: next));
  }

  Future<bool> changeCardControls(
    CardControls controls, {
    required Future<String?> Function() requestCode,
  }) => _changeCard(requestCode, (token, code) => _api.setCardControls(token, code, controls));

  Future<bool> _changeCard(
    Future<String?> Function() requestCode,
    Future<BankAccount> Function(String token, String code) update,
  ) async {
    final token = this.token;
    if (token == null || _cardPending) return false;
    _cardPending = true;
    final version = _sessionVersion;
    try {
      final code = await requestCode();
      if (code == null || !signedIn || version != _sessionVersion) return false;
      final account = await update(token, code);
      if (version != _sessionVersion) return false;
      _account = account;
      notifyListeners();
      return true;
    } on BankApiException catch (error) {
      if (error.status == 401 && version == _sessionVersion) {
        _token = null;
        lock();
        return false;
      }
      rethrow;
    } finally {
      _cardPending = false;
    }
  }
}
