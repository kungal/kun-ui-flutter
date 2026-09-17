import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

/// One contract name and how this port answers for it.
class CoverageEntry {
  const CoverageEntry({
    required this.section,
    required this.contractName,
    required this.status,
    this.dartName,
    this.shownBy,
    this.reason,
  });

  final String section;
  final String contractName;
  final CoverageStatus status;
  final String? dartName;
  final String? shownBy;
  final String? reason;
}

enum CoverageStatus {
  shown,
  notYet,
  noVisualForm,
  omitted;

  String get label => switch (this) {
        CoverageStatus.shown => 'shown',
        CoverageStatus.notYet => 'not yet',
        CoverageStatus.noVisualForm => 'no visual form',
        CoverageStatus.omitted => 'omitted',
      };

  KunUIColor get color => switch (this) {
        CoverageStatus.shown => KunUIColor.success,
        CoverageStatus.notYet => KunUIColor.warning,
        CoverageStatus.noVisualForm => KunUIColor.info,
        CoverageStatus.omitted => KunUIColor.neutral,
      };
}

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
    final TextStyle headerStyle = KunText.base.copyWith(
      fontWeight: KunFontWeights.semibold,
    );
    final TextStyle sectionStyle = KunText.sm.copyWith(
      fontWeight: KunFontWeights.semibold,
    );
    final TextStyle mutedStyle = KunText.sm.copyWith(
      color: theme.colors.neutral.shade600,
    );

    int shown = 0;
    int notYet = 0;
    int noVisualForm = 0;
    int omitted = 0;
    for (final CoverageEntry entry in coverage.entries) {
      switch (entry.status) {
        case CoverageStatus.shown:
          shown += 1;
        case CoverageStatus.notYet:
          notYet += 1;
        case CoverageStatus.noVisualForm:
          noVisualForm += 1;
        case CoverageStatus.omitted:
          omitted += 1;
      }
    }
    final int total = coverage.entries.length;

    final List<Widget> children = <Widget>[
      Text(coverage.name, style: headerStyle),
      Text(
        '$shown ${CoverageStatus.shown.label}, '
        '$notYet ${CoverageStatus.notYet.label}, '
        '$noVisualForm ${CoverageStatus.noVisualForm.label}, '
        '$omitted ${CoverageStatus.omitted.label}, of $total',
      ),
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
          spacing: KunSpacing.unit * 3,
          children: <Widget>[
            Text(section, style: sectionStyle),
            for (final CoverageEntry entry in group) _entry(entry, mutedStyle),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(KunSpacing.unit * 6),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: theme.breakpoints.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: KunSpacing.unit * 5,
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
          spacing: KunSpacing.unit * 3,
          runSpacing: KunSpacing.unit * 3,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            KunChip(
              variant: KunUIVariant.flat,
              color: entry.status.color,
              size: KunUISize.xs,
              child: Text(entry.status.label),
            ),
            Text(entry.contractName),
            Text(entry.dartName ?? '-'),
            if (entry.shownBy != null) Text(entry.shownBy!, style: mutedStyle),
          ],
        ),
        if (entry.reason != null) Text(entry.reason!, style: mutedStyle),
      ],
    );
  }
}
