import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

/// One contract name and how this port answers for it.
class CoverageEntry {
  const CoverageEntry({
    required this.section,
    required this.contractName,
    this.dartName,
    this.shownBy,
    this.reason,
  });

  final String section;
  final String contractName;
  final String? dartName;
  final String? shownBy;
  final String? reason;

  CoverageStatus get status => dartName == null
      ? CoverageStatus.omitted
      : shownBy != null
          ? CoverageStatus.shown
          : CoverageStatus.gap;
}

enum CoverageStatus { shown, gap, omitted }

/// One component's contract coverage, as the manifest and the spec record it.
class ComponentCoverage {
  const ComponentCoverage({required this.name, required this.entries});

  final String name;
  final List<CoverageEntry> entries;
}

/// A chrome-less listing of one component's contract names and how they are shown.
class CoveragePage extends StatelessWidget {
  const CoveragePage({required this.coverage, super.key});

  final ComponentCoverage coverage;

  @override
  Widget build(BuildContext context) {
    final KunThemeData theme = KunTheme.of(context);
    final TextStyle headerStyle =
        KunControlMetrics.of(KunUISize.lg).textStyle.copyWith(
              fontWeight: FontWeight.w600,
            );
    final TextStyle sectionStyle =
        KunControlMetrics.of(KunUISize.md).textStyle.copyWith(
              fontWeight: FontWeight.w600,
            );
    final TextStyle mutedStyle =
        KunControlMetrics.of(KunUISize.sm).textStyle.copyWith(
              color: theme.colors.neutral.shade600,
            );

    int shown = 0;
    int gap = 0;
    int omitted = 0;
    for (final CoverageEntry entry in coverage.entries) {
      switch (entry.status) {
        case CoverageStatus.shown:
          shown += 1;
        case CoverageStatus.gap:
          gap += 1;
        case CoverageStatus.omitted:
          omitted += 1;
      }
    }
    final int total = coverage.entries.length;

    final List<Widget> children = <Widget>[
      Text(coverage.name, style: headerStyle),
      Text('$shown shown / $gap gap / $omitted omitted of $total'),
    ];
    for (final String section in <String>['props', 'events', 'slots']) {
      final List<CoverageEntry> group = <CoverageEntry>[
        for (final CoverageEntry entry in coverage.entries)
          if (entry.section == section) entry,
      ];
      if (group.isEmpty) continue;
      children.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: KunCardPadding.sm.value,
          children: <Widget>[
            Text(section, style: sectionStyle),
            for (final CoverageEntry entry in group) _entry(entry, mutedStyle),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(KunCardPadding.lg.value),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: theme.breakpoints.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: KunCardPadding.md.value,
          children: children,
        ),
      ),
    );
  }

  Widget _entry(CoverageEntry entry, TextStyle mutedStyle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Wrap(
          spacing: KunCardPadding.sm.value,
          runSpacing: KunCardPadding.sm.value,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            KunChip(
              variant: KunUIVariant.flat,
              color: switch (entry.status) {
                CoverageStatus.shown => KunUIColor.success,
                CoverageStatus.gap => KunUIColor.warning,
                CoverageStatus.omitted => KunUIColor.neutral,
              },
              size: KunUISize.xs,
              child: Text(entry.status.name),
            ),
            Text(entry.contractName),
            Text(entry.dartName ?? '-'),
          ],
        ),
        if (entry.reason != null) Text(entry.reason!, style: mutedStyle),
      ],
    );
  }
}
