import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spendkit_ui/spendkit_ui.dart';

import '../core.dart';
import '../data.dart';
import 'bank_widgets.dart';
import 'screen_body.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  final _merchant = TextEditingController();
  SpendCategory? _category;
  DateTimeRange? _range;

  @override
  void dispose() {
    _merchant.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(sessionProvider).account.today;
    return ScreenBody(
      children: [
        const SpendHeading(
          'Activity',
          subtitle: 'Find and review business card transactions.',
        ),
        SpendPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SpendField(
                label: 'Search merchant',
                controller: _merchant,
                prefixIcon: Icons.search,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              DropdownMenu<int>(
                expandedInsets: EdgeInsets.zero,
                label: const Text('Category'),
                initialSelection: _category?.index ?? -1,
                onSelected: (value) => setState(() {
                  _category = value == null || value < 0
                      ? null
                      : SpendCategory.values[value];
                }),
                dropdownMenuEntries: [
                  const DropdownMenuEntry(value: -1, label: 'All categories'),
                  for (final category in SpendCategory.values)
                    DropdownMenuEntry(
                      value: category.index,
                      label: category.label,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _range == null
                          ? 'Date range'
                          : '${shortDate(_range!.start)} – ${shortDate(_range!.end)}',
                    ),
                    onPressed: () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(today.year, today.month - 5),
                        lastDate: today,
                        initialDateRange: _range,
                      );
                      if (mounted && range != null) {
                        setState(() => _range = range);
                      }
                    },
                  ),
                  if (_range != null)
                    TextButton(
                      onPressed: () => setState(() => _range = null),
                      child: const Text('Clear dates'),
                    ),
                ],
              ),
            ],
          ),
        ),
        TransactionData(
          items: ref.watch(transactionsProvider),
          onRetry: () => ref.invalidate(transactionsProvider),
          builder: (items) {
            final matches = filterTransactions(
              items,
              merchant: _merchant.text,
              category: _category,
              start: _range?.start,
              end: _range?.end,
            );
            return SpendPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      '${matches.length} ${matches.length == 1 ? 'transaction' : 'transactions'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (matches.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: SpendNotice(
                        message: 'No transactions match these filters.',
                      ),
                    ),
                  for (final item in matches) TransactionRow(item),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
