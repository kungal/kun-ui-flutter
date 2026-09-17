import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

const List<KunSelectOption<String>> _frameworks = <KunSelectOption<String>>[
  KunSelectOption<String>(value: 'vue', label: 'Vue'),
  KunSelectOption<String>(value: 'react', label: 'React'),
  KunSelectOption<String>(value: 'solid', label: 'Solid'),
  KunSelectOption<String>(value: 'svelte', label: 'Svelte'),
  KunSelectOption<String>(value: 'angular', label: 'Angular', disabled: true),
];

const List<KunSelectOption<String>> _frameworksNoSvelte =
    <KunSelectOption<String>>[
  KunSelectOption<String>(value: 'vue', label: 'Vue'),
  KunSelectOption<String>(value: 'react', label: 'React'),
  KunSelectOption<String>(value: 'solid', label: 'Solid'),
  KunSelectOption<String>(value: 'angular', label: 'Angular', disabled: true),
];

const List<KunSelectOption<String>> _frameworksPlusQwik =
    <KunSelectOption<String>>[
  KunSelectOption<String>(value: 'vue', label: 'Vue'),
  KunSelectOption<String>(value: 'react', label: 'React'),
  KunSelectOption<String>(value: 'solid', label: 'Solid'),
  KunSelectOption<String>(value: 'svelte', label: 'Svelte'),
  KunSelectOption<String>(value: 'angular', label: 'Angular', disabled: true),
  KunSelectOption<String>(value: 'qwik', label: 'Qwik'),
];

const List<KunSelectOption<String>> _colorOptions = <KunSelectOption<String>>[
  KunSelectOption<String>(value: 'vue', label: 'Vue'),
  KunSelectOption<String>(value: 'react', label: 'React'),
  KunSelectOption<String>(value: 'solid', label: 'Solid'),
];

const List<KunSelectOption<String>> _clearableOptions =
    <KunSelectOption<String>>[
  KunSelectOption<String>(value: 'vue', label: 'Vue'),
  KunSelectOption<String>(value: 'react', label: 'React'),
  KunSelectOption<String>(value: 'solid', label: 'Solid'),
  KunSelectOption<String>(value: 'svelte', label: 'Svelte'),
];

const List<KunSelectOption<String>> _errorOptions = <KunSelectOption<String>>[
  KunSelectOption<String>(value: 'vue', label: 'Vue'),
  KunSelectOption<String>(value: 'react', label: 'React'),
  KunSelectOption<String>(value: 'solid', label: 'Solid'),
];

const List<_UserOption> _assignees = <_UserOption>[
  _UserOption(
    value: 'kun',
    label: 'Kun',
    initial: 'K',
    color: Color(0xFFE11D48),
    description: '前端 · Vue',
  ),
  _UserOption(
    value: 'moe',
    label: 'Moe',
    initial: 'M',
    color: Color(0xFF2563EB),
    description: '设计',
  ),
  _UserOption(
    value: 'rin',
    label: 'Rin',
    initial: 'R',
    color: Color(0xFF16A34A),
    description: '后端 · Rust',
  ),
];

const List<KunSelectOption<String>> _catalog = <KunSelectOption<String>>[
  KunSelectOption<String>(value: 'clannad', label: 'CLANNAD'),
  KunSelectOption<String>(value: 'kanon', label: 'Kanon'),
  KunSelectOption<String>(value: 'air', label: 'AIR'),
  KunSelectOption<String>(value: 'little-busters', label: 'Little Busters!'),
  KunSelectOption<String>(value: 'rewrite', label: 'Rewrite'),
  KunSelectOption<String>(
    value: 'summer-pockets',
    label: 'Summer Pockets',
  ),
  KunSelectOption<String>(value: 'steins-gate', label: 'STEINS;GATE'),
  KunSelectOption<String>(value: 'chaos-head', label: 'CHAOS;HEAD'),
  KunSelectOption<String>(
    value: 'robotics-notes',
    label: 'ROBOTICS;NOTES',
  ),
  KunSelectOption<String>(value: 'muv-luv', label: 'Muv-Luv'),
  KunSelectOption<String>(value: 'fate-stay-night', label: 'Fate/stay night'),
  KunSelectOption<String>(value: 'tsukihime', label: '月姫'),
];

const List<KunSelectOption<String>> _tagOptions = <KunSelectOption<String>>[
  KunSelectOption<String>(value: '催泪', label: '催泪'),
  KunSelectOption<String>(value: '校园', label: '校园'),
  KunSelectOption<String>(value: '科幻', label: '科幻'),
  KunSelectOption<String>(value: '悬疑', label: '悬疑'),
  KunSelectOption<String>(value: '奇幻', label: '奇幻'),
  KunSelectOption<String>(value: '夏天', label: '夏天'),
  KunSelectOption<String>(value: '战斗', label: '战斗'),
];

const List<KunSelectOption<String>> _platformOptions =
    <KunSelectOption<String>>[
  KunSelectOption<String>(value: 'PC', label: 'PC'),
  KunSelectOption<String>(value: 'Switch', label: 'Switch'),
  KunSelectOption<String>(value: 'PS5', label: 'PS5'),
];

const List<KunSelectOption<String>> _statusOptions = <KunSelectOption<String>>[
  KunSelectOption<String>(value: '已完成', label: '已完成'),
  KunSelectOption<String>(value: '进行中', label: '进行中'),
  KunSelectOption<String>(value: '待校对', label: '待校对'),
];

const List<_Work> _works = <_Work>[
  _Work(
    title: 'CLANNAD',
    year: 2004,
    platform: 'PC',
    status: '已完成',
    tags: <String>['催泪', '校园'],
  ),
  _Work(
    title: 'STEINS;GATE',
    year: 2009,
    platform: 'PC',
    status: '已完成',
    tags: <String>['科幻', '悬疑'],
  ),
  _Work(
    title: 'Summer Pockets',
    year: 2018,
    platform: 'Switch',
    status: '进行中',
    tags: <String>['夏天', '催泪'],
  ),
  _Work(
    title: 'Muv-Luv Alternative',
    year: 2006,
    platform: 'PC',
    status: '待校对',
    tags: <String>['科幻', '战斗'],
  ),
  _Work(
    title: '月姫 -A piece of blue glass moon-',
    year: 2021,
    platform: 'PS5',
    status: '进行中',
    tags: <String>['奇幻', '悬疑'],
  ),
  _Work(
    title: 'Little Busters!',
    year: 2007,
    platform: 'Switch',
    status: '已完成',
    tags: <String>['校园', '催泪'],
  ),
];

class _UserOption extends KunSelectOption<String> {
  const _UserOption({
    required super.value,
    required super.label,
    required this.initial,
    required this.color,
    required this.description,
  });

  final String initial;
  final Color color;
  final String description;
}

class _Work {
  const _Work({
    required this.title,
    required this.year,
    required this.platform,
    required this.status,
    required this.tags,
  });

  final String title;
  final int year;
  final String platform;
  final String status;
  final List<String> tags;
}

Widget _caption(BuildContext context, String text) {
  final KunColorScheme scheme = KunTheme.of(context).colors;
  return Text(
    text.toUpperCase(),
    style: KunText.xs.copyWith(color: scheme.neutral.shade500),
  );
}

Widget selectBasic(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: KunContainerWidths.xs),
      child: _SingleSelect(
        options: _frameworks,
        initial: 'vue',
        label: 'Framework',
      ),
    ),
  );
}

Widget selectClearable(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: KunContainerWidths.xs),
      child: _SingleSelect(
        options: _clearableOptions,
        initial: 'vue',
        label: 'Framework',
        clearable: true,
        placeholder: 'None selected',
      ),
    ),
  );
}

Widget selectColors(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: KunContainerWidths.xs),
      child: _ColorSelects(),
    ),
  );
}

Widget selectCustomOption(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: KunContainerWidths.xs),
      child: _CustomOptionSelect(),
    ),
  );
}

Widget selectDisabled(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: KunContainerWidths.xs),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        spacing: KunSpacing.unit * 4,
        children: <Widget>[
          _SingleSelect(
            options: _frameworksNoSvelte,
            initial: 'vue',
            label: '禁用选项 (Angular)',
          ),
          _SingleSelect(
            options: _frameworksNoSvelte,
            initial: 'react',
            label: '禁用整个组件',
            disabled: true,
          ),
        ],
      ),
    ),
  );
}

Widget selectError(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: KunContainerWidths.xs),
      child: _SingleSelect(
        options: _errorOptions,
        label: 'Framework',
        placeholder: '请选择',
        error: '此项为必填项',
      ),
    ),
  );
}

Widget selectMultiple(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: KunContainerWidths.xs),
      child: _MultipleSelect(),
    ),
  );
}

Widget selectSearchable(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: KunContainerWidths.xs),
      child: _SingleSelect(
        options: _frameworksPlusQwik,
        initial: 'vue',
        label: 'Framework',
        searchable: true,
      ),
    ),
  );
}

Widget selectAsync(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: KunContainerWidths.sm),
      child: _AsyncSelect(),
    ),
  );
}

Widget selectFilterBar(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: _FilterBar(),
  );
}

Widget selectInModal(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: _SelectInModal(),
  );
}

Widget selectSizes(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: [
        for (final KunUISize size in KunUISize.values) ...[
          _caption(context, size.name),
          Wrap(
            spacing: KunSpacing.unit * 3,
            runSpacing: KunSpacing.unit * 3,
            children: [
              for (final KunUIRounded rounded in KunUIRounded.values)
                _SingleSelect(
                  options: _colorOptions,
                  initial: 'vue',
                  size: size,
                  rounded: rounded,
                  fullWidth: false,
                  label: rounded.name,
                  description:
                      size == KunUISize.md && rounded == KunUIRounded.md
                          ? 'size × rounded'
                          : null,
                ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _SingleSelect extends StatefulWidget {
  const _SingleSelect({
    required this.options,
    this.initial,
    this.label,
    this.placeholder,
    this.description,
    this.error,
    this.size = KunUISize.md,
    this.rounded,
    this.disabled = false,
    this.clearable = false,
    this.fullWidth = true,
    this.searchable = false,
  });

  final List<KunSelectOption<String>> options;
  final String? initial;
  final String? label;
  final String? placeholder;
  final String? description;
  final String? error;
  final KunUISize size;
  final KunUIRounded? rounded;
  final bool disabled;
  final bool clearable;
  final bool fullWidth;
  final bool searchable;

  @override
  State<_SingleSelect> createState() => _SingleSelectState();
}

class _SingleSelectState extends State<_SingleSelect> {
  late String? _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return KunSelect<String, KunSelectOption<String>>(
      options: widget.options,
      value: _value,
      onChanged: (String? next) => setState(() => _value = next),
      label: widget.label,
      placeholder: widget.placeholder,
      description: widget.description,
      error: widget.error,
      size: widget.size,
      rounded: widget.rounded,
      disabled: widget.disabled,
      clearable: widget.clearable,
      fullWidth: widget.fullWidth,
      searchable: widget.searchable,
    );
  }
}

class _ColorSelects extends StatefulWidget {
  const _ColorSelects();

  @override
  State<_ColorSelects> createState() => _ColorSelectsState();
}

class _ColorSelectsState extends State<_ColorSelects> {
  String? _value = 'vue';

  static const List<(KunUIColor, String)> _colors = <(KunUIColor, String)>[
    (KunUIColor.primary, 'primary'),
    (KunUIColor.secondary, 'secondary'),
    (KunUIColor.success, 'success'),
    (KunUIColor.warning, 'warning'),
    (KunUIColor.danger, 'danger'),
    (KunUIColor.info, 'info'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: KunSpacing.unit * 4,
      children: [
        for (final (KunUIColor color, String name) in _colors)
          KunSelect<String, KunSelectOption<String>>(
            options: _colorOptions,
            value: _value,
            onChanged: (String? next) => setState(() => _value = next),
            color: color,
            label: name,
          ),
      ],
    );
  }
}

class _CustomOptionSelect extends StatefulWidget {
  const _CustomOptionSelect();

  @override
  State<_CustomOptionSelect> createState() => _CustomOptionSelectState();
}

class _CustomOptionSelectState extends State<_CustomOptionSelect> {
  String? _value = 'kun';

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return KunSelect<String, _UserOption>(
      options: _assignees,
      value: _value,
      onChanged: (String? next) => setState(() => _value = next),
      label: 'Assignee',
      optionBuilder: (
        BuildContext context,
        _UserOption option,
        int index,
        bool active,
        bool selected,
      ) {
        return Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: option.color,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: KunSpacing.unit * 8,
                child: Center(
                  child: Text(
                    option.initial,
                    style: KunText.sm.copyWith(
                      color: KunColors.white,
                      fontWeight: KunFontWeights.medium,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: KunSpacing.unit * 2),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KunText.sm.copyWith(
                      fontWeight: KunFontWeights.medium,
                    ),
                  ),
                  Text(
                    option.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KunText.xs.copyWith(
                      color: scheme.neutral.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MultipleSelect extends StatefulWidget {
  const _MultipleSelect();

  @override
  State<_MultipleSelect> createState() => _MultipleSelectState();
}

class _MultipleSelectState extends State<_MultipleSelect> {
  List<String> _values = <String>['vue', 'solid'];

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KunSelect<String, KunSelectOption<String>>.multiple(
          options: _frameworksPlusQwik,
          values: _values,
          onValuesChanged: (List<String> next) =>
              setState(() => _values = next),
          label: 'Frameworks',
          searchable: true,
        ),
        SizedBox(height: KunSpacing.unit * 2),
        Text(
          '值: ${_values.isEmpty ? '—' : _values.join(', ')}',
          style: KunText.sm.copyWith(color: scheme.neutral.shade500),
        ),
      ],
    );
  }
}

class _AsyncSelect extends StatefulWidget {
  const _AsyncSelect();

  @override
  State<_AsyncSelect> createState() => _AsyncSelectState();
}

class _AsyncSelectState extends State<_AsyncSelect> {
  List<String> _values = <String>[];
  List<KunSelectOption<String>> _options = <KunSelectOption<String>>[];
  bool _loading = false;
  int _seq = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onSearch(String query) {
    final int mine = ++_seq;
    _timer?.cancel();
    setState(() => _loading = true);
    _timer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted || mine != _seq) {
        return;
      }
      final String q = query.trim().toLowerCase();
      setState(() {
        _options = _catalog
            .where(
              (KunSelectOption<String> o) => o.label.toLowerCase().contains(q),
            )
            .take(6)
            .toList();
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KunSelect<String, KunSelectOption<String>>.multiple(
          options: _options,
          values: _values,
          onValuesChanged: (List<String> next) =>
              setState(() => _values = next),
          onSearch: _onSearch,
          label: '收录作品',
          placeholder: '搜索作品名',
          searchable: true,
          manualFilter: true,
          loading: _loading,
          debounce: const Duration(milliseconds: 300),
          searchPlaceholder: '输入至少一个字…',
          noResultText: '没有匹配的作品',
        ),
        SizedBox(height: KunSpacing.unit * 2),
        Text(
          '已选 ${_values.length} 项：${_values.isEmpty ? '—' : _values.join('、')}',
          style: KunText.sm.copyWith(color: scheme.neutral.shade500),
        ),
        SizedBox(height: KunSpacing.unit),
        Text(
          '选中一项后再搜别的词——标签不会丢，组件为当前选中的值保留了最后一次见到的 option。',
          style: KunText.xs.copyWith(color: scheme.neutral.shade500),
        ),
      ],
    );
  }
}

class _FilterBar extends StatefulWidget {
  const _FilterBar();

  @override
  State<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<_FilterBar> {
  List<String> _tags = <String>['催泪'];
  List<String> _platforms = <String>[];
  String? _status;

  List<_Work> get _results => _works.where((_Work w) {
        final bool tagsOk =
            _tags.isEmpty || _tags.any((String t) => w.tags.contains(t));
        final bool platformsOk =
            _platforms.isEmpty || _platforms.contains(w.platform);
        final bool statusOk = _status == null || w.status == _status;
        return tagsOk && platformsOk && statusOk;
      }).toList();

  void _reset() {
    setState(() {
      _tags = <String>[];
      _platforms = <String>[];
      _status = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final List<_Work> results = _results;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: KunSpacing.unit * 2,
          runSpacing: KunSpacing.unit * 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            KunSelect<String, KunSelectOption<String>>.multiple(
              options: _tagOptions,
              values: _tags,
              onValuesChanged: (List<String> next) =>
                  setState(() => _tags = next),
              searchable: true,
              fullWidth: false,
              maxVisibleTags: 0,
              popupWidth: KunSelectPopupWidth.auto,
              rounded: KunUIRounded.full,
              size: KunUISize.sm,
              icon: KunIcons.filter,
              placeholder: '标签',
              semanticLabel: '按标签筛选',
            ),
            KunSelect<String, KunSelectOption<String>>.multiple(
              options: _platformOptions,
              values: _platforms,
              onValuesChanged: (List<String> next) =>
                  setState(() => _platforms = next),
              fullWidth: false,
              maxVisibleTags: 1,
              popupWidth: KunSelectPopupWidth.auto,
              rounded: KunUIRounded.full,
              size: KunUISize.sm,
              placeholder: '平台',
              semanticLabel: '按平台筛选',
            ),
            KunSelect<String, KunSelectOption<String>>(
              options: _statusOptions,
              value: _status,
              onChanged: (String? next) => setState(() => _status = next),
              fullWidth: false,
              clearable: true,
              popupWidth: KunSelectPopupWidth.auto,
              rounded: KunUIRounded.full,
              size: KunUISize.sm,
              placeholder: '状态',
              semanticLabel: '按状态筛选',
            ),
            KunButton(
              size: KunUISize.sm,
              variant: KunUIVariant.light,
              onPressed: _reset,
              child: const Text('重置'),
            ),
          ],
        ),
        SizedBox(height: KunSpacing.unit * 4),
        if (results.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: KunSpacing.unit * 6),
            child: Center(
              child: Text(
                '没有符合条件的作品',
                style: KunText.sm.copyWith(color: scheme.neutral.shade500),
              ),
            ),
          )
        else
          Column(
            mainAxisSize: MainAxisSize.min,
            spacing: KunSpacing.unit * 2,
            children: [
              for (final _Work work in results)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.content1,
                    border: Border.all(color: scheme.border),
                    borderRadius: BorderRadius.circular(KunRadius.lg),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KunSpacing.unit * 3,
                      vertical: KunSpacing.unit * 2,
                    ),
                    child: Row(
                      spacing: KunSpacing.unit * 3,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                work.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: KunText.sm.copyWith(
                                  fontWeight: KunFontWeights.medium,
                                ),
                              ),
                              Text(
                                '${work.year} · ${work.platform} · ${work.tags.join('／')}',
                                style: KunText.xs.copyWith(
                                  color: scheme.neutral.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        KunChip(
                          size: KunUISize.sm,
                          variant: KunUIVariant.flat,
                          child: Text(work.status),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _SelectInModal extends StatefulWidget {
  const _SelectInModal();

  @override
  State<_SelectInModal> createState() => _SelectInModalState();
}

class _SelectInModalState extends State<_SelectInModal> {
  bool _open = false;
  String? _value = 'vue';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        KunButton(
          onPressed: () => setState(() => _open = true),
          child: const Text('Open modal'),
        ),
        KunModal(
          value: _open,
          onChanged: (bool next) => setState(() => _open = next),
          title: 'Form',
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: KunContainerWidths.xs),
            child: KunSelect<String, KunSelectOption<String>>(
              options: _frameworks,
              value: _value,
              onChanged: (String? next) => setState(() => _value = next),
              label: 'Framework',
              searchable: true,
            ),
          ),
        ),
      ],
    );
  }
}
