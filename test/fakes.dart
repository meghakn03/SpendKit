import 'package:spendkit/src/core.dart';

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
