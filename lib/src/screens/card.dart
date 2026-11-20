import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spendkit_ui/spendkit_ui.dart';

import '../core.dart';
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

  Future<void> _changeCard() async {
    final session = ref.read(sessionProvider);
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    try {
      final changed = await session.changeCard(
        requestCode: () {
          if (!mounted) return Future<String?>.value();
          return showDialog<String>(
            context: context,
            builder: (_) => const _VerifyDialog(),
          );
        },
      );
      if (mounted && changed) {
        setState(
          () => _status = session.frozen ? 'Card frozen.' : 'Card unfrozen.',
        );
      }
    } on Exception {
      if (mounted) {
        setState(
          () => _error = 'The card status could not be saved. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final frozen = ref.watch(sessionProvider).frozen;
    final repo = ref.watch(repositoryProvider);
    return ScreenBody(
      children: [
        const SpendHeading(
          'Your card',
          subtitle: 'Manage your Studio North virtual card.',
        ),
        CreditCardSummary(
          available: repo.availablePence,
          limit: repo.limitPence,
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
            value?.trim() == demoCode ? null : 'Enter the correct access code.',
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
