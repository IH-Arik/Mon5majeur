import 'package:flutter/material.dart';

import '../../../../data/services/night_top_scores.dart';

/// Loads the night's top 3 fantasy scorers for [date] (a match date) and hands
/// them to [builder]: an empty map until known, or when [date] is not the last
/// published night.
class NightTopBuilder extends StatefulWidget {
  final String? date;
  final Widget Function(Map<String, int> medals) builder;

  const NightTopBuilder({super.key, required this.date, required this.builder});

  @override
  State<NightTopBuilder> createState() => _NightTopBuilderState();
}

class _NightTopBuilderState extends State<NightTopBuilder> {
  Map<String, int> _medals = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(NightTopBuilder old) {
    super.didUpdateWidget(old);
    if (old.date != widget.date) {
      _medals = const {};
      _load();
    }
  }

  void _load() {
    final date = widget.date;
    NightTopScores.forDate(date).then((m) {
      if (mounted && date == widget.date) setState(() => _medals = m);
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(_medals);
}
