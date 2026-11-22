import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spendkit_ui/spendkit_ui.dart';

import '../bank_api.dart';
import '../core.dart';
import '../data.dart';
import 'bank_widgets.dart';
import 'screen_body.dart';

class CardScreen extends ConsumerStatefulWidget {
  const CardScreen({super.key});

  @override
  ConsumerState<CardScreen> createState() => _CardScreenState();
}

class _CardScreenState extends ConsumerState<CardScreen> {
  bool _busy = false;
  String? _error;
  String? _status;

  Future<String?> _requestCode() {
    if (!mounted) return Future<String?>.value();
    return showDialog<String>(
      context: context,
      builder: (_) => const _VerifyDialog(),
    );
  }

  Future<void> _changeCard() {
    final session = ref.read(sessionProvider);
    return _saveCard(
      () => session.changeCard(requestCode: _requestCode),
      () => session.frozen ? 'Card frozen.' : 'Card unfrozen.',
    );
  }

  Future<void> _editControls() async {
    final session = ref.read(sessionProvider);
    final controls = await showDialog<CardControls>(
      context: context,
      builder: (_) => _CardControlsDialog(account: session.account),
    );
    if (!mounted || controls == null) return;
    await _saveCard(
      () => session.changeCardControls(controls, requestCode: _requestCode),
      () => 'Spending controls saved.',
    );
  }

  Future<void> _saveCard(
    Future<bool> Function() save,
    String Function() successMessage,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    try {
      final changed = await save();
      if (mounted && changed) {
        setState(() => _status = successMessage());
      }
    } on BankApiException catch (failure) {
      if (mounted) {
        setState(
          () => _error = failure.status == 403
              ? 'Enter the correct access code.'
              : failure.message,
        );
      }
    } on Exception {
      if (mounted) {
        setState(
          () => _error = 'The card changes could not be saved. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final frozen = ref.watch(sessionProvider).frozen;
    final account = ref.watch(sessionProvider).account;
    return ScreenBody(
      children: [
        const SpendHeading(
          'Your card',
          subtitle: 'Manage your Studio North virtual card.',
        ),
        CreditCardSummary(
          available: account.availablePence,
          limit: account.limitPence,
          frozen: frozen,
        ),
        SpendPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Card controls',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                frozen
                    ? 'New card payments are blocked.'
                    : 'Freeze this card to block new card payments.',
              ),
              const SizedBox(height: 16),
              SpendButton(
                label: frozen ? 'Unfreeze card' : 'Freeze card',
                icon: Icons.ac_unit,
                onPressed: _busy ? null : _changeCard,
              ),
              if ((_error ?? _status) case final message?) ...[
                const SizedBox(height: 12),
                SpendNotice(message: message, error: _error != null),
              ],
            ],
          ),
        ),
        SpendPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Spending controls',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Per-transaction limit · ${pounds(account.transactionLimitPence)}',
              ),
              Text(
                'ATM withdrawals · ${account.atmBlocked ? 'Blocked' : 'Allowed'}',
              ),
              const SizedBox(height: 16),
              SpendButton(
                label: 'Edit spending controls',
                icon: Icons.tune,
                onPressed: _busy ? null : _editControls,
              ),
              TextButton.icon(
                onPressed: () => context.go('/card/simulator'),
                icon: const Icon(Icons.science_outlined),
                label: const Text('Test card controls'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VerifyDialog extends StatefulWidget {
  const _VerifyDialog();

  @override
  State<_VerifyDialog> createState() => _VerifyDialogState();
}

class _VerifyDialogState extends State<_VerifyDialog> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Verify access'),
    content: Form(
      key: _form,
      child: SpendField(
        label: 'Enter access code',
        controller: _code,
        obscureText: true,
        validator: (value) =>
            value?.trim().isNotEmpty == true ? null : 'Enter your access code.',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      SpendButton(
        label: 'Confirm',
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _code.text.trim());
          }
        },
      ),
    ],
  );
}

class _CardControlsDialog extends StatefulWidget {
  const _CardControlsDialog({required this.account});

  final BankAccount account;

  @override
  State<_CardControlsDialog> createState() => _CardControlsDialogState();
}

class _CardControlsDialogState extends State<_CardControlsDialog> {
  final _form = GlobalKey<FormState>();
  late final _limit = TextEditingController(
    text: (widget.account.transactionLimitPence / 100).toStringAsFixed(2),
  );
  late bool _atmBlocked = widget.account.atmBlocked;

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Edit spending controls'),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _limit,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Per-transaction limit',
              prefixText: '£',
              errorMaxLines: 2,
            ),
            validator: (value) {
              final pence = parsePounds(value);
              if (pence == null ||
                  pence < 1 ||
                  pence > widget.account.limitPence) {
                return 'Enter an amount from £0.01 to ${pounds(widget.account.limitPence)}.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Block ATM withdrawals'),
            value: _atmBlocked,
            onChanged: (value) => setState(() => _atmBlocked = value),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      SpendButton(
        label: 'Continue to verification',
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, (
              transactionLimitPence: parsePounds(_limit.text)!,
              atmBlocked: _atmBlocked,
            ));
          }
        },
      ),
    ],
  );
}
