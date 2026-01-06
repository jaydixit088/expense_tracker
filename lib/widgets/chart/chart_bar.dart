import 'package:flutter/material.dart';

/// A single vertical bar used within the `Chart` widget.
/// Its height is determined by the `fill` factor, which should be a value
/// between 0.0 and 1.0.
class ChartBar extends StatelessWidget {
  const ChartBar({
    super.key,
    required this.fill,
  });

  final double fill;

  @override
  Widget build(BuildContext context) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;

    // The Expanded widget ensures that each bar takes up equal width in the chart's Row.
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        // This widget sizes its child to a fraction of the total available height.
        child: FractionallySizedBox(
          heightFactor: fill, // e.g., 0.5 means the bar will take up 50% of the available height.
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
              color: isDarkMode
                  ? Theme.of(context).colorScheme.secondary
                  : Theme.of(context).colorScheme.primary.withOpacity(0.65),
            ),
          ),
        ),
      ),
    );
  }
}
