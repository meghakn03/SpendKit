import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'data.dart';

class BankAccount {
  const BankAccount({
    required this.availablePence,
    required this.limitPence,
    required this.frozen,
    required this.transactionLimitPence,
    required this.atmBlocked,
    required this.today,
  });

  factory BankAccount.fromJson(Map<String, dynamic> json) => BankAccount(
    availablePence: json['availablePence'] as int,
    limitPence: json['limitPence'] as int,
    frozen: json['frozen'] as bool,
    transactionLimitPence: json['transactionLimitPence'] as int,
    atmBlocked: json['atmBlocked'] as bool,
    today: DateTime.parse(json['today'] as String),
  );

  final int availablePence;
  final int limitPence;
  final bool frozen;
  final int transactionLimitPence;
  final bool atmBlocked;
  final DateTime today;
}

typedef CardControls = ({int transactionLimitPence, bool atmBlocked});

typedef BankSession = ({String token, BankAccount account});

class BankApiException implements Exception {
  const BankApiException(this.message, {this.status});
  final String message;
  final int? status;
}

abstract interface class BankApi {
  Future<BankSession> signIn(String code);
  Future<BankAccount> account(String token);
  Future<List<Transaction>> transactions(String token);
  Future<BankAccount> setCard(
    String token,
    String code, {
    required bool frozen,
  });
  Future<BankAccount> setCardControls(
    String token,
    String code,
    CardControls controls,
  );
  Future<void> revoke(String token);
}

class HttpBankApi implements BankApi {
  HttpBankApi(this._client);

  final http.Client _client;

  static Uri _endpoint(String path) {
    const configuredUrl = String.fromEnvironment('SPENDKIT_API_URL');
    final host = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : '127.0.0.1';
    final base = configuredUrl.isEmpty ? 'http://$host:8787' : configuredUrl;
    return Uri.parse('${base.replaceFirst(RegExp(r'/$'), '')}/$path');
  }

  Future<Object?> _request(
    String method,
    String path, {
    String? token,
    Map<String, Object>? body,
  }) async {
    final request = http.Request(method, _endpoint(path));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode >= 400) {
        throw BankApiException(
          'The request could not be completed.',
          status: response.statusCode,
        );
      }
      if (response.statusCode == 204) return null;
      return jsonDecode(response.body);
    } on http.ClientException {
      throw const BankApiException('Could not reach the SpendKit server.');
    } on TimeoutException {
      throw const BankApiException(
        'The SpendKit server took too long to respond.',
      );
    } on FormatException {
      throw const BankApiException(
        'The SpendKit server returned an invalid response.',
      );
    }
  }

  @override
  Future<BankSession> signIn(String code) async {
    final json = await _request(
      'POST',
      'session',
      body: {'code': code},
    ) as Map<String, dynamic>;
    return (
      token: json['token'] as String,
      account: BankAccount.fromJson(json['account'] as Map<String, dynamic>),
    );
  }

  @override
  Future<BankAccount> account(String token) async => BankAccount.fromJson(
    await _request('GET', 'account', token: token) as Map<String, dynamic>,
  );

  @override
  Future<List<Transaction>> transactions(String token) async {
    final rows =
        await _request('GET', 'transactions', token: token) as List<dynamic>;
    return rows.map((row) {
      final json = row as Map<String, dynamic>;
      return Transaction(
        json['merchant'] as String,
        SpendCategory.values.byName(json['category'] as String),
        DateTime.parse(json['date'] as String),
        json['pence'] as int,
      );
    }).toList();
  }

  @override
  Future<BankAccount> setCard(
    String token,
    String code, {
    required bool frozen,
  }) async => BankAccount.fromJson(
    await _request(
      'PUT',
      'card',
      token: token,
      body: {'code': code, 'frozen': frozen},
    ) as Map<String, dynamic>,
  );

  @override
  Future<BankAccount> setCardControls(
    String token,
    String code,
    CardControls controls,
  ) async => BankAccount.fromJson(
    await _request(
      'PUT',
      'card/controls',
      token: token,
      body: {
        'code': code,
        'transactionLimitPence': controls.transactionLimitPence,
        'atmBlocked': controls.atmBlocked,
      },
    ) as Map<String, dynamic>,
  );

  @override
  Future<void> revoke(String token) async {
    await _request('DELETE', 'session', token: token);
  }
}
