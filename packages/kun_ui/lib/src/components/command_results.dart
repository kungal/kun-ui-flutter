import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_icons/kun_ui_icons.dart';
import 'package:kun_ui_messages/kun_ui_messages.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../foundation/motion.dart';
import '../foundation/tap_target.dart';
import '../locale/messages.dart';
import '../theme/theme.dart';
import 'command_palette.dart';

/// One item in the flattened command list, with its global index.
@immutable
class KunCommandRow {
  /// Creates a flattened row.
  const KunCommandRow({required this.item, required this.index});

  /// The item to draw.
  final KunCommandItem item;

  /// Global index among every item in every non-empty group, used for
  /// highlighting and `aria-activedescendant`.
  final int index;
}

/// A labelled cluster of flattened [KunCommandRow]s.
///
/// Empty groups are dropped by [kunCommandToRows] before this is built.
@immutable
class KunCommandRowGroup {
  /// Creates a flattened group.
  const KunCommandRowGroup({this.label, required this.items});

  /// Optional heading. Null or empty draws no heading and no group wrapper.
  final String? label;

  /// Rows in this group, in order, carrying their global [KunCommandRow.index].
  final List<KunCommandRow> items;
}

/// Maps [KunCommandGroup]s to flattened rows, dropping empty groups.
///
/// Matches `toCommandRows` in kun-ui `utils/commandItems.ts`.
List<KunCommandRowGroup> kunCommandToRows(List<KunCommandGroup> items) {
  int i = 0;
  return <KunCommandRowGroup>[
    for (final KunCommandGroup group in items)
      if (group.items.isNotEmpty)
        KunCommandRowGroup(
          label: group.label,
          items: <KunCommandRow>[
            for (final KunCommandItem item in group.items)
              KunCommandRow(item: item, index: i++),
          ],
        ),
  ];
}

/// Every item in [groups], in global-index order.
List<KunCommandItem> kunCommandFlat(List<KunCommandRowGroup> groups) {
  return <KunCommandItem>[
    for (final KunCommandRowGroup group in groups)
      for (final KunCommandRow row in group.items) row.item,
  ];
}

/// Split [text] on [terms] (case-insensitive). The web escapes HTML before
/// wrapping a match in `<mark>`; there is no HTML here, so those steps have
/// no counterpart. Regex metacharacters in a term are still escaped so the
/// split stays a literal match.
List<InlineSpan> kunCommandHighlightSpans(
  String text,
  List<String> terms,
  TextStyle base,
  KunColorScheme scheme,
) {
  if (terms.isEmpty) {
    return <InlineSpan>[TextSpan(text: text, style: base)];
  }
  final String pattern = terms.map(RegExp.escape).join('|');
  final RegExp re = RegExp('($pattern)', caseSensitive: false);
  final TextStyle mark = base.copyWith(
    backgroundColor: scheme.primary.solid.withValues(alpha: 0.2),
    color: scheme.foreground,
  );
  final List<InlineSpan> spans = <InlineSpan>[];
  int start = 0;
  for (final RegExpMatch match in re.allMatches(text)) {
    if (match.start > start) {
      spans.add(
        TextSpan(text: text.substring(start, match.start), style: base),
      );
    }
    spans.add(TextSpan(text: match.group(0), style: mark));
    start = match.end;
  }
  if (start < text.length) {
    spans.add(TextSpan(text: text.substring(start), style: base));
  }
  if (spans.isEmpty) {
    spans.add(TextSpan(text: text, style: base));
  }
  return spans;
}

/// Query terms used by the default row highlighter.
List<String> kunCommandHighlightTerms(String query, {required bool enabled}) {
  if (!enabled) {
    return const <String>[];
  }
  return query
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((String t) => t.isNotEmpty)
      .toList();
}

/// Group headers and command rows shared by [KunCommandPalette] and
/// [KunCommandSearch].
///
/// Look and interaction match the palette's previous private widgets
/// byte for byte: active `bg-primary/10`, a non-active hovered row
/// `hover:bg-default-100`, the default icon/section/label/description
/// layout, and a pointer-only remove control on `removable` rows.
class KunCommandResults extends StatelessWidget {
  /// Creates the shared results list.
  const KunCommandResults({
    super.key,
    required this.groups,
    required this.activeIndex,
    required this.hoveredIndex,
    required this.query,
    required this.highlight,
    required this.itemKeyPrefix,
    required this.rowKey,
    required this.onSelect,
    required this.onHover,
    required this.onPointerEnter,
    required this.onPointerExit,
    required this.onRemove,
    this.onListExit,
    this.itemBuilder,
  });

  /// Flattened groups, empty groups already dropped.
  final List<KunCommandRowGroup> groups;

  /// Highlighted row index, or `-1` when none.
  final int activeIndex;

  /// Row currently under the pointer, for the non-active hover fill.
  final int? hoveredIndex;

  /// Current query, used by the default highlighter.
  final String query;

  /// Whether the default row wraps query terms.
  final bool highlight;

  /// Prefix of each row's [ValueKey], e.g. `KunCommandPalette.item`.
  final String itemKeyPrefix;

  /// [GlobalKey] for scrolling a row into view.
  final GlobalKey Function(int index) rowKey;

  /// Activating a row (tap or Enter).
  final ValueChanged<KunCommandItem> onSelect;

  /// Pointer moved onto an enabled row; the parent sets the highlight.
  final ValueChanged<int> onHover;

  /// Pointer entered a row, for the non-active hover fill.
  final ValueChanged<int> onPointerEnter;

  /// Pointer left a row.
  final ValueChanged<int> onPointerExit;

  /// Remove control or the row's custom semantics action.
  final void Function(KunCommandItem item, int index) onRemove;

  /// Pointer left the list. [KunCommandSearch] clears the highlight.
  final VoidCallback? onListExit;

  /// Custom row. The default paints the icon, section, highlighted label
  /// and description.
  final Widget Function(
    BuildContext context,
    KunCommandItem item,
    bool active,
  )? itemBuilder;

  @override
  Widget build(BuildContext context) {
    Widget list = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int gi = 0; gi < groups.length; gi++)
          _KunCommandResultGroup(
            group: groups[gi],
            last: gi == groups.length - 1,
            activeIndex: activeIndex,
            hoveredIndex: hoveredIndex,
            query: query,
            highlight: highlight,
            itemKeyPrefix: itemKeyPrefix,
            rowKey: rowKey,
            itemBuilder: itemBuilder,
            onSelect: onSelect,
            onHover: onHover,
            onPointerEnter: onPointerEnter,
            onPointerExit: onPointerExit,
            onRemove: onRemove,
          ),
      ],
    );
    final VoidCallback? onListExit = this.onListExit;
    if (onListExit != null) {
      list = MouseRegion(
        onExit: (_) => onListExit(),
        child: list,
      );
    }
    return list;
  }
}

class _KunCommandResultGroup extends StatelessWidget {
  const _KunCommandResultGroup({
    required this.group,
    required this.last,
    required this.activeIndex,
    required this.hoveredIndex,
    required this.query,
    required this.highlight,
    required this.itemKeyPrefix,
    required this.rowKey,
    required this.itemBuilder,
    required this.onSelect,
    required this.onHover,
    required this.onPointerEnter,
    required this.onPointerExit,
    required this.onRemove,
  });

  final KunCommandRowGroup group;
  final bool last;
  final int activeIndex;
  final int? hoveredIndex;
  final String query;
  final bool highlight;
  final String itemKeyPrefix;
  final GlobalKey Function(int index) rowKey;
  final Widget Function(BuildContext, KunCommandItem, bool)? itemBuilder;
  final ValueChanged<KunCommandItem> onSelect;
  final ValueChanged<int> onHover;
  final ValueChanged<int> onPointerEnter;
  final ValueChanged<int> onPointerExit;
  final void Function(KunCommandItem item, int index) onRemove;

  bool get _labelled => group.label != null && group.label!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final Widget column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_labelled)
          Semantics(
            header: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                KunSpacing.unit * 3,
                KunSpacing.unit * 2,
                KunSpacing.unit * 3,
                KunSpacing.unit * 1,
              ),
              child: Text(
                group.label!,
                style: KunText.xs.copyWith(
                  color: scheme.foregroundMuted,
                  fontWeight: KunFontWeights.medium,
                ),
              ),
            ),
          ),
        for (final KunCommandRow row in group.items)
          _KunCommandResultRow(
            item: row.item,
            index: row.index,
            active: row.index == activeIndex,
            hovered: hoveredIndex == row.index,
            query: query,
            highlight: highlight,
            itemKeyPrefix: itemKeyPrefix,
            rowKey: rowKey(row.index),
            itemBuilder: itemBuilder,
            onSelect: onSelect,
            onHover: onHover,
            onPointerEnter: onPointerEnter,
            onPointerExit: onPointerExit,
            onRemove: onRemove,
          ),
      ],
    );
    return Padding(
      padding: EdgeInsets.only(
        bottom: last ? 0 : KunSpacing.unit * 1,
      ),
      child: column,
    );
  }
}

class _KunCommandResultRow extends StatelessWidget {
  const _KunCommandResultRow({
    required this.item,
    required this.index,
    required this.active,
    required this.hovered,
    required this.query,
    required this.highlight,
    required this.itemKeyPrefix,
    required this.rowKey,
    required this.itemBuilder,
    required this.onSelect,
    required this.onHover,
    required this.onPointerEnter,
    required this.onPointerExit,
    required this.onRemove,
  });

  final KunCommandItem item;
  final int index;
  final bool active;
  final bool hovered;
  final String query;
  final bool highlight;
  final String itemKeyPrefix;
  final GlobalKey rowKey;
  final Widget Function(BuildContext, KunCommandItem, bool)? itemBuilder;
  final ValueChanged<KunCommandItem> onSelect;
  final ValueChanged<int> onHover;
  final ValueChanged<int> onPointerEnter;
  final ValueChanged<int> onPointerExit;
  final void Function(KunCommandItem item, int index) onRemove;

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final KunCommandPaletteStrings strings =
        KunMessagesScope.of(context).commandPalette;
    final Widget content = itemBuilder?.call(context, item, active) ??
        _KunCommandDefaultRow(
          item: item,
          query: query,
          highlight: highlight,
        );
    // CommandResults.vue `bg-primary/10` on the active row,
    // `hover:bg-default-100` on any other row under the pointer.
    final Color? fill = active
        ? scheme.primary.solid.withValues(alpha: 0.1)
        : hovered && !item.disabled
            ? scheme.neutral.shade100.withValues(alpha: KunColors.globalOpacity)
            : null;

    final String label = item.description == null || item.description!.isEmpty
        ? item.label
        : '${item.label}\n${item.description}';

    final bool canRemove = item.removable && !item.disabled;
    final Map<CustomSemanticsAction, VoidCallback>? actions = canRemove
        ? <CustomSemanticsAction, VoidCallback>{
            CustomSemanticsAction(label: strings.remove): () =>
                onRemove(item, index),
          }
        : null;

    final Widget visual = MouseRegion(
      cursor:
          item.disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onHover: item.disabled ? null : (_) => onHover(index),
      onEnter: (_) => onPointerEnter(index),
      onExit: (_) => onPointerExit(index),
      child: GestureDetector(
        key: rowKey,
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: itemBuilder == null,
        onTap: item.disabled ? null : () => onSelect(item),
        child: AnimatedContainer(
          duration: kunMotion(context, KunDefaultTransition.duration),
          curve: KunDefaultTransition.curve,
          constraints: BoxConstraints(
            minHeight: kunMinTapTargetSize(context).height,
          ),
          alignment: AlignmentDirectional.centerStart,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(KunRadius.md),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: KunSpacing.unit * 3,
            vertical: KunSpacing.unit * 2,
          ),
          child: Opacity(
            opacity: item.disabled ? 0.5 : 1,
            child: Row(
              children: <Widget>[
                Expanded(child: content),
                if (canRemove)
                  _KunCommandRemoveButton(
                    onPressed: () => onRemove(item, index),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    final Key rowIdentity =
        ValueKey<String>('$itemKeyPrefix.${item.resolvedValue}');
    final Widget node = Semantics(
      key: itemBuilder == null ? rowIdentity : null,
      container: itemBuilder == null,
      role: SemanticsRole.listItem,
      label: itemBuilder == null ? label : null,
      selected: active,
      enabled: !item.disabled,
      button: item.href == null,
      link: item.href != null,
      onTap: item.disabled ? null : () => onSelect(item),
      customSemanticsActions: actions,
      child: itemBuilder == null ? ExcludeSemantics(child: visual) : visual,
    );
    if (itemBuilder == null) {
      return node;
    }
    return MergeSemantics(key: rowIdentity, child: node);
  }
}

class _KunCommandDefaultRow extends StatelessWidget {
  const _KunCommandDefaultRow({
    required this.item,
    required this.query,
    required this.highlight,
  });

  final KunCommandItem item;
  final String query;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final List<String> terms =
        kunCommandHighlightTerms(query, enabled: highlight);
    return Row(
      children: <Widget>[
        if (item.icon != null) ...<Widget>[
          Icon(
            item.icon,
            size: KunText.base.fontSize,
            color: scheme.neutral.shade500,
          ),
          SizedBox(width: KunSpacing.unit * 3),
        ],
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (item.section != null && item.section!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: KunSpacing.unit * 0.5),
                  child: Text(
                    item.section!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KunText.xs.copyWith(
                      color: scheme.foregroundMuted,
                    ),
                  ),
                ),
              Text.rich(
                TextSpan(
                  children: kunCommandHighlightSpans(
                    item.label,
                    terms,
                    KunText.sm.copyWith(
                      color: scheme.foreground,
                      fontWeight: KunFontWeights.medium,
                    ),
                    scheme,
                  ),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (item.description != null && item.description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: KunSpacing.unit * 0.5),
                  child: Text.rich(
                    TextSpan(
                      children: kunCommandHighlightSpans(
                        item.description!,
                        terms,
                        KunText.xs.copyWith(
                          color: scheme.foregroundMuted,
                        ),
                        scheme,
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// CommandResults.vue `size-6` remove control, pointer-only.
class _KunCommandRemoveButton extends StatefulWidget {
  const _KunCommandRemoveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_KunCommandRemoveButton> createState() =>
      _KunCommandRemoveButtonState();
}

class _KunCommandRemoveButtonState extends State<_KunCommandRemoveButton> {
  bool _hovered = false;

  static const double _drawn = KunSpacing.unit * 6;

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final TextDirection direction = Directionality.of(context);
    final Widget face = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: widget.onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _hovered ? scheme.neutral.shade200 : null,
            borderRadius: BorderRadius.circular(KunRadius.sm),
          ),
          child: SizedBox.square(
            dimension: _drawn,
            child: Icon(
              KunIcons.x,
              size: KunSpacing.unit * 3.5,
              color:
                  _hovered ? scheme.neutral.shade700 : scheme.neutral.shade400,
            ),
          ),
        ),
      ),
    );
    return Transform.translate(
      offset: Offset(
        direction == TextDirection.rtl ? -KunSpacing.unit : KunSpacing.unit,
        0,
      ),
      child: KunTapTarget(child: face),
    );
  }
}
