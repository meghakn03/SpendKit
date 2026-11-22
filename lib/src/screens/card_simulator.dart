import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spendkit_ui/spendkit_ui.dart';

import '../bank_api.dart';
import '../core.dart';
import '../data.dart';
import 'screen_body.dart';

class CardSimulatorScreen extends ConsumerStatefulWidget {
  const CardSimulatorScreen({super.key});

  @override
  ConsumerState<CardSimulatorScreen> createState() =>
      _CardSimulatorScreenState();
}

class _CardSimulatorScreenState extends ConsumerState<CardSimulatorScreen> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController(text: '600.00');
  SimulationChannel _channel = SimulationChannel.purchase;
  CardSimulation? _result;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _simulate() async {
    if (!_form.currentState!.validate()) return;
    final token = ref.read(sessionProvider).token;
    if (token == null) return;
    final pence = parsePounds(_amount.text)!;
    final channel = _channel;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _result = null;
      _error = null;
    });
    try {
      final result = await ref
          .read(bankApiProvider)
          .simulate(token, pence, channel);
      if (mounted && ref.read(sessionProvider).token == token) {
        setState(() => _result = result);
      }
    } on BankApiException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.status == 401
              ? 'This session expired. Lock the workspace and sign in again.'
              : error.message,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = _result?.account ?? ref.watch(sessionProvider).account;
    return ScreenBody(
      maxWidth: 600,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go('/card'),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to card'),
          ),
        ),
        const SpendHeading(
          'Card simulator',
          subtitle: 'Test a purchase or ATM withdrawal against your current settings. No money moves.',
        ),
        SpendPanel(
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (channel, label, icon) in [
                      (
                        SimulationChannel.purchase,
                        'Purchase',
                        Icons.shopping_bag_outlined,
                      ),
                      (
                        SimulationChannel.atm,
                        'ATM withdrawal',
                        Icons.local_atm_outlined,
                      ),
                    ])
                      ChoiceChip(
                        avatar: Icon(icon, size: 18),
                        label: Text(label),
                        selected: _channel == channel,
                        onSelected: _busy
                            ? null
                            : (_) => setState(() {
                                _channel = channel;
                                _result = null;
                                _error = null;
                              }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  enabled: !_busy,
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount in pounds',
                    prefixText: '£',
                  ),
                  validator: (value) => (parsePounds(value) ?? 0) > 0
                      ? null
                      : 'Enter an amount greater than zero.',
                  onChanged: (_) {
                    if (_result != null || _error != null) {
                      setState(() {
                        _result = null;
                        _error = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                SpendButton(
                  label: 'Run simulation',
                  icon: Icons.play_arrow_rounded,
                  busy: _busy,
                  onPressed: _simulate,
                ),
              ],
            ),
          ),
        ),
        if (_result case final result?) _DecisionPanel(reason: result.reason),
        if (_error case final error?) SpendNotice(message: error, error: true),
        SpendPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rules in effect',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text('Card status · ${account.frozen ? 'Frozen' : 'Active'}'),
              Text(
                'Transaction limit · ${pounds(account.transactionLimitPence)}',
              ),
              Text(
                'ATM withdrawals · ${account.atmBlocked ? 'Blocked' : 'Allowed'}',
              ),
              Text('Available credit · ${pounds(account.availablePence)}'),
            ],
          ),
        ),
      ],
    );
  }
}

class _DecisionPanel extends StatelessWidget {
  const _DecisionPanel({required this.reason});
  final SimulationReason reason;

  @override
  Widget build(BuildContext context) {
    final approved = reason == SimulationReason.approved;
    final colors = Theme.of(context).colorScheme;
    final foreground = approved
        ? colors.onPrimaryContainer
        : colors.onErrorContainer;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: approved ? colors.primaryContainer : colors.errorContainer,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                approved ? Icons.check_circle_outline : Icons.block,
                color: foreground,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      approved ? 'Approved' : 'Declined',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      reason.explanation,
                      style: TextStyle(color: foreground),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
