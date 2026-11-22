import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spendkit_ui/spendkit_ui.dart';

import '../bank_api.dart';
import '../core.dart';
import 'screen_body.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _authenticate(
    Future<bool> Function() action,
    String rejectedMessage,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    String? error;
    try {
      if (!await action()) error = rejectedMessage;
    } on BankApiException catch (failure) {
      error = failure.message;
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    return Scaffold(
      body: SafeArea(
        child: ScreenBody(
          maxWidth: 480,
          children: [
            const SizedBox(height: 34),
            Align(
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: SpendColors.mint,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    color: SpendColors.ink,
                    size: 30,
                  ),
                ),
              ),
            ),
            const SpendHeading(
              'SpendKit',
              subtitle: 'Business spending, all in one place.',
            ),
            SpendPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Sign in to your workspace',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  const SpendNotice(
                    message: 'Demo workspace · Enter access code 2048.',
                  ),
                  const SizedBox(height: 16),
                  SpendField(
                    label: 'Access code',
                    controller: _code,
                    obscureText: true,
                    prefixIcon: Icons.lock_outline,
                  ),
                  if (_error case final error?) ...[
                    const SizedBox(height: 12),
                    SpendNotice(message: error, error: true),
                  ],
                  const SizedBox(height: 16),
                  SpendButton(
                    label: 'Sign in',
                    icon: Icons.arrow_forward,
                    busy: _busy,
                    onPressed: () => _authenticate(
                      () => session.signIn(_code.text.trim()),
                      'That access code is incorrect.',
                    ),
                  ),
                  if (session.canUnlock)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _authenticate(
                              session.unlock,
                              'Biometric unlock was unavailable. Enter your access code.',
                            ),
                      child: const Text('Unlock with biometrics'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
