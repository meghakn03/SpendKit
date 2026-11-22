import 'package:spendkit/src/bank_api.dart';
import 'package:spendkit/src/core.dart';
import 'package:spendkit/src/data.dart';

class MemoryPreferences implements Preferences {
  final values = <String, bool>{};

  @override
  Future<bool?> getBool(String key) async => values[key];

  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;
}

class FakeBiometrics implements Biometrics {
  bool approved = false;

  @override
  Future<bool> authenticate(String reason) async => approved;
}

class FakeBankApi implements BankApi {
  int _counter = 0;
  final _tokens = <String>{};
  final _today = DateTime(2026, 11, 20);
  bool frozen = false;
  CardControls _controls = (transactionLimitPence: 50000, atmBlocked: false);

  @override
  Future<BankSession> signIn(String code) async {
    if (code != demoCode) {
      throw const BankApiException('Invalid code', status: 401);
    }
    final token = 'demo-${_counter++}';
    _tokens.add(token);
    return (token: token, account: await account(token));
  }

  @override
  Future<BankAccount> account(String token) async {
    if (!_tokens.contains(token)) {
      throw const BankApiException('Invalid session', status: 401);
    }
    return BankAccount(
      availablePence: 842560,
      limitPence: 1200000,
      frozen: frozen,
      transactionLimitPence: _controls.transactionLimitPence,
      atmBlocked: _controls.atmBlocked,
      today: _today,
    );
  }

  @override
  Future<List<Transaction>> transactions(String token) async {
    await account(token);
    return [Transaction('Figma', SpendCategory.software, _today, 7200)];
  }

  @override
  Future<BankAccount> setCard(
    String token,
    String code, {
    required bool frozen,
  }) async {
    await account(token);
    if (code != demoCode) {
      throw const BankApiException('Invalid code', status: 403);
    }
    this.frozen = frozen;
    return account(token);
  }

  @override
  Future<BankAccount> setCardControls(
    String token,
    String code,
    CardControls controls,
  ) async {
    await account(token);
    if (code != demoCode) {
      throw const BankApiException('Invalid code', status: 403);
    }
    _controls = controls;
    return account(token);
  }

  @override
  Future<CardSimulation> simulate(
    String token,
    int pence,
    SimulationChannel channel,
  ) async =>
      (reason: SimulationReason.cardFrozen, account: await account(token));

  @override
  Future<void> revoke(String token) async {
    _tokens.remove(token);
  }
}
