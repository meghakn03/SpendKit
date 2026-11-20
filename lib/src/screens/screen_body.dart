import 'package:material_ui/material_ui.dart';
import 'package:spendkit_ui/spendkit_ui.dart';

class ScreenBody extends StatelessWidget {
  const ScreenBody({super.key, required this.children, this.maxWidth = 920});
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0) const SizedBox(height: SpendSpace.medium),
            child,
          ],
        ],
      ),
    ),
  );
}
