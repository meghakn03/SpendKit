import 'package:material_ui/material_ui.dart';
import 'package:spendkit_ui/spendkit_ui.dart';

import '../data.dart';

class SpendingPanel extends StatefulWidget {
  const SpendingPanel({
    super.key,
    required this.transactions,
    required this.today,
  });
  final List<Transaction> transactions;
  final DateTime today;

  @override
  State<SpendingPanel> createState() => _SpendingPanelState();
}

class _SpendingPanelState extends State<SpendingPanel> {
  int _offset = 0;

  @override
  Widget build(BuildContext context) {
    final date = DateTime(widget.today.year, widget.today.month - _offset);
    final totals = spendingByCategory(widget.transactions, date);
    final sum = totals.values.fold(0, (a, b) => a + b);
    final months = [
      for (var offset = 5; offset >= 0; offset--)
        DateTime(widget.today.year, widget.today.month - offset),
    ];
    final history = months
        .map(
          (month) => spendingByCategory(
            widget.transactions,
            month,
          ).values.fold(0, (a, b) => a + b),
        )
        .toList();
    final peak = history.reduce((a, b) => a > b ? a : b);
    final colors = Theme.of(context).colorScheme;
    return SpendPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SpendHeading('Monthly spending'),
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: _offset == 5
                    ? null
                    : () => setState(() => _offset++),
                icon: const Icon(Icons.chevron_left),
              ),
              Semantics(
                liveRegion: true,
                child: Text('${monthNames[date.month - 1]} ${date.year}'),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: _offset == 0
                    ? null
                    : () => setState(() => _offset--),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Text(pounds(sum), style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (index, month) in months.indexed)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: index == 5 - _offset,
                    label:
                        '${monthNames[month.month - 1]} ${month.year}, ${pounds(history[index])}',
                    child: InkWell(
                      onTap: () => setState(() => _offset = 5 - index),
                      borderRadius: BorderRadius.circular(10),
                      child: ExcludeSemantics(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 3,
                            vertical: 8,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: 74,
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: AnimatedContainer(
                                    duration:
                                        MediaQuery.disableAnimationsOf(context)
                                        ? Duration.zero
                                        : const Duration(milliseconds: 220),
                                    width: 28,
                                    height: peak == 0
                                        ? 4
                                        : 4 + 70 * history[index] / peak,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(7),
                                      color: index == 5 - _offset
                                          ? colors.primary
                                          : colors.secondaryContainer,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                monthNames[month.month - 1].substring(0, 3),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const Divider(),
          for (final entry in totals.entries)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${entry.key.label} · ${pounds(entry.value)}'),
                  const SizedBox(height: 6),
                  ExcludeSemantics(
                    child: LinearProgressIndicator(
                      value: sum == 0 ? 0 : entry.value / sum,
                      minHeight: 7,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
