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
