import 'dart:ui' show Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Finder get trigger => find.byKey(const ValueKey<String>('KunSelect.trigger'));
Finder get popup => find.byKey(const ValueKey<String>('KunSelect.popup'));
Finder get popupFade =>
    find.byKey(const ValueKey<String>('KunSelect.popupFade'));
Finder get popupScale =>
    find.byKey(const ValueKey<String>('KunSelect.popupScale'));
Finder get chevron => find.byKey(const ValueKey<String>('KunSelect.chevron'));
Finder optionAt(int index) =>
    find.byKey(ValueKey<String>('KunSelect.option.$index'));

const List<KunSelectOption<String>> frameworks = <KunSelectOption<String>>[
  KunSelectOption<String>(value: 'vue', label: 'Vue'),
  KunSelectOption<String>(value: 'react', label: 'React'),
  KunSelectOption<String>(value: 'solid', label: 'Solid'),
  KunSelectOption<String>(value: 'svelte', label: 'Svelte'),
  KunSelectOption<String>(value: 'angular', label: 'Angular', disabled: true),
];

Widget wrap(
  Widget child, {
  KunThemeData? theme,
  Widget Function(Widget child)? wrapHome,
}) {
  Widget home = child;
  if (wrapHome != null) {
    home = wrapHome(child);
  }
  return KunTheme(
    data: theme ?? KunThemeData.light(),
    child: WidgetsApp(
      color: KunColors.black,
      debugShowCheckedModeBanner: false,
      home: home,
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) {
        return PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
            return builder(context);
          },
        );
      },
    ),
  );
}

Widget wrapWebKeys(Widget child) => wrap(
      Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.enter): ButtonActivateIntent(),
        },
        child: child,
      ),
    );

void setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

BoxDecoration triggerDecoration(WidgetTester tester) {
  return tester.widget<Container>(trigger).decoration! as BoxDecoration;
}

TextStyle resolvedOf(WidgetTester tester, String text) {
  return (tester
          .widget<RichText>(
            find.descendant(
              of: find.text(text),
              matching: find.byType(RichText),
            ),
          )
          .text as TextSpan)
      .style!;
}

Future<void> openByTap(WidgetTester tester) async {
  await tester.tap(trigger);
  await tester.pump();
  await tester.pump(KunDurations.base);
}

class _Host extends StatefulWidget {
  const _Host({
    super.key,
    this.options = frameworks,
    this.initial,
    this.initialValues = const <String>[],
    this.multiple = false,
    this.maxVisibleTags,
    this.placeholder,
    this.label,
    this.description,
    this.error,
    this.semanticLabel,
    this.size = KunUISize.md,
    this.rounded,
    this.disabled = false,
    this.clearable = false,
    this.fullWidth = true,
    this.searchable = false,
    this.manualFilter = false,
    this.loading = false,
    this.debounce = Duration.zero,
    this.noResultText,
    this.loadingText,
    this.popupWidth = KunSelectPopupWidth.trigger,
    this.onSearch,
  });

  final List<KunSelectOption<String>> options;
  final String? initial;
  final List<String> initialValues;
  final bool multiple;
  final int? maxVisibleTags;
  final String? placeholder;
  final String? label;
  final String? description;
  final String? error;
  final String? semanticLabel;
  final KunUISize size;
  final KunUIRounded? rounded;
  final bool disabled;
  final bool clearable;
  final bool fullWidth;
  final bool searchable;
  final bool manualFilter;
  final bool loading;
  final Duration debounce;
  final String? noResultText;
  final String? loadingText;
  final KunSelectPopupWidth popupWidth;
  final ValueChanged<String>? onSearch;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late String? value = widget.initial;
  late List<String> values = List<String>.of(widget.initialValues);
  final List<String?> changed = <String?>[];
  final List<List<String>> valuesChanged = <List<String>>[];
  final List<(String, int)> sets = <(String, int)>[];
  final List<String> searches = <String>[];

  void updateValue(String? next) => setState(() => value = next);

  @override
  void didUpdateWidget(_Host oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initial != widget.initial) {
      value = widget.initial;
    }
    if (!listEquals(oldWidget.initialValues, widget.initialValues)) {
      values = List<String>.of(widget.initialValues);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.multiple) {
      return KunSelect<String, KunSelectOption<String>>.multiple(
        options: widget.options,
        values: values,
        onValuesChanged: (List<String> next) {
          valuesChanged.add(List<String>.of(next));
          setState(() => values = next);
        },
        onSet: (String v, int i) => sets.add((v, i)),
        onSearch: (String q) {
          searches.add(q);
          widget.onSearch?.call(q);
        },
        label: widget.label,
        placeholder: widget.placeholder,
        description: widget.description,
        error: widget.error,
        semanticLabel: widget.semanticLabel,
        size: widget.size,
        rounded: widget.rounded,
        disabled: widget.disabled,
        clearable: widget.clearable,
        fullWidth: widget.fullWidth,
        searchable: widget.searchable,
        manualFilter: widget.manualFilter,
        loading: widget.loading,
        debounce: widget.debounce,
        noResultText: widget.noResultText,
        loadingText: widget.loadingText,
        popupWidth: widget.popupWidth,
        maxVisibleTags: widget.maxVisibleTags,
      );
    }
    return KunSelect<String, KunSelectOption<String>>(
      options: widget.options,
      value: value,
      onChanged: (String? next) {
        changed.add(next);
        setState(() => value = next);
      },
      onSet: (String v, int i) => sets.add((v, i)),
      onSearch: (String q) {
        searches.add(q);
        widget.onSearch?.call(q);
      },
      label: widget.label,
      placeholder: widget.placeholder,
      description: widget.description,
      error: widget.error,
      semanticLabel: widget.semanticLabel,
      size: widget.size,
      rounded: widget.rounded,
      disabled: widget.disabled,
      clearable: widget.clearable,
      fullWidth: widget.fullWidth,
      searchable: widget.searchable,
      manualFilter: widget.manualFilter,
      loading: widget.loading,
      debounce: widget.debounce,
      noResultText: widget.noResultText,
      loadingText: widget.loadingText,
      popupWidth: widget.popupWidth,
    );
  }
}

class _NamedOption extends KunSelectOption<String> {
  const _NamedOption({
    required super.value,
    required super.label,
    required this.description,
  });

  final String description;
}

void main() {
  testWidgets('trigger text: chosen label, placeholder, raw value',
      (WidgetTester tester) async {
    final GlobalKey<_HostState> key = GlobalKey<_HostState>();
    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 320,
            child: _Host(
              key: key,
              placeholder: 'Pick one',
            ),
          ),
        ),
      ),
    );
    expect(find.text('Pick one'), findsOneWidget);

    key.currentState!.updateValue('vue');
    await tester.pump();
    expect(find.text('Vue'), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 320,
            child: _Host(
              initial: 'missing',
              placeholder: 'Pick one',
            ),
          ),
        ),
      ),
    );
    expect(find.text('missing'), findsOneWidget);
  });

  testWidgets('chips follow selection order, cache, maxVisibleTags',
      (WidgetTester tester) async {
    final GlobalKey<_HostState> key = GlobalKey<_HostState>();
    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 360,
            child: _Host(
              key: key,
              multiple: true,
              initialValues: const <String>['solid', 'vue', 'react'],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Solid'), findsOneWidget);
    expect(find.text('Vue'), findsOneWidget);
    expect(find.text('React'), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 360,
            child: _Host(
              key: key,
              multiple: true,
              initialValues: const <String>['solid', 'vue', 'react'],
              options: const <KunSelectOption<String>>[
                KunSelectOption<String>(value: 'react', label: 'React'),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Solid'), findsOneWidget);
    expect(find.text('Vue'), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 360,
            child: _Host(
              multiple: true,
              initialValues: const <String>['vue', 'react', 'solid'],
              maxVisibleTags: 1,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Vue'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
    expect(find.text('React'), findsNothing);

    await tester.pumpWidget(
      wrap(
        Center(
          child: _Host(
            multiple: true,
            initialValues: const <String>['vue', 'react'],
            maxVisibleTags: 0,
            placeholder: '标签',
            fullWidth: false,
          ),
        ),
      ),
    );
    expect(find.text('标签 · 2'), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        Center(
          child: _Host(
            multiple: true,
            initialValues: const <String>['vue', 'react'],
            maxVisibleTags: 0,
            fullWidth: false,
          ),
        ),
      ),
    );
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('tap opens and closes; outside tap closes without moving focus',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        const Center(
          child: SizedBox(width: 320, child: _Host()),
        ),
      ),
    );
    expect(popup, findsNothing);
    await tester.tap(trigger);
    await tester.pump();
    await tester.pump(KunDurations.base);
    expect(popup, findsOneWidget);
    await tester.tap(trigger);
    await tester.pump();
    await tester.pump(KunDurations.exit);
    await tester.pump();
    expect(popup, findsNothing);

    await tester.tap(trigger);
    await tester.pump();
    await tester.pump(KunDurations.base);
    expect(
      Focus.of(tester.element(trigger)).hasFocus,
      isTrue,
    );
    await tester.tapAt(const Offset(8, 8));
    await tester.pump();
    await tester.pump(KunDurations.exit);
    await tester.pump();
    expect(popup, findsNothing);
    expect(
      Focus.of(tester.element(trigger)).hasFocus,
      isTrue,
    );
  });

  testWidgets('Escape and Tab close and focus the trigger',
      (WidgetTester tester) async {
    await tester.pumpWidget(
        wrap(const Center(child: SizedBox(width: 320, child: _Host()))));
    await openByTap(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(popup, findsNothing);
    expect(Focus.of(tester.element(trigger)).hasFocus, isTrue);

    await openByTap(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(popup, findsNothing);
    expect(Focus.of(tester.element(trigger)).hasFocus, isTrue);
  });

  testWidgets('disabled never opens and cannot take focus',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        const Center(
          child: SizedBox(width: 320, child: _Host(disabled: true)),
        ),
      ),
    );
    await tester.tap(trigger, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(popup, findsNothing);
    expect(
      tester
          .widget<Focus>(
            find
                .descendant(
                  of: find.byType(KunSelect<String, KunSelectOption<String>>),
                  matching: find.byType(Focus),
                )
                .at(1),
          )
          .canRequestFocus,
      isFalse,
    );
  });

  testWidgets('closed ArrowDown, ArrowUp, Enter and Space open',
      (WidgetTester tester) async {
    Future<void> expectOpensOn(LogicalKeyboardKey key) async {
      await tester.pumpWidget(
        wrap(
          Center(
            child: SizedBox(
              width: 320,
              child: _Host(key: UniqueKey()),
            ),
          ),
        ),
      );
      Focus.of(tester.element(trigger)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
      expect(popup, findsOneWidget, reason: key.debugName);
    }

    await expectOpensOn(LogicalKeyboardKey.arrowDown);
    await expectOpensOn(LogicalKeyboardKey.arrowUp);
    await expectOpensOn(LogicalKeyboardKey.enter);
    await expectOpensOn(LogicalKeyboardKey.space);
  });

  testWidgets('open keyboard wraps, skips disabled, Home/End, Enter, Space',
      (WidgetTester tester) async {
    final GlobalKey<_HostState> key = GlobalKey<_HostState>();
    await tester.pumpWidget(
      wrapWebKeys(
        Center(
          child: SizedBox(
            width: 320,
            child: _Host(key: key, initial: 'vue'),
          ),
        ),
      ),
    );
    await openByTap(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(key.currentState!.value, 'react');
    expect(key.currentState!.sets.last.$1, 'react');

    await tester.pumpWidget(
      wrapWebKeys(
        Center(
          child: SizedBox(
            width: 320,
            child: _Host(key: key, initial: 'vue'),
          ),
        ),
      ),
    );
    await openByTap(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(key.currentState!.value, 'svelte');

    await tester.pumpWidget(
      wrapWebKeys(
        Center(
          child: SizedBox(
            width: 320,
            child: _Host(key: key, initial: 'svelte'),
          ),
        ),
      ),
    );
    await openByTap(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(key.currentState!.value, 'vue');
    expect(popup, findsNothing);

    final GlobalKey<_HostState> wrapKey = GlobalKey<_HostState>();
    await tester.pumpWidget(
      wrapWebKeys(
        Center(
          child: SizedBox(
            width: 320,
            child: _Host(key: wrapKey, initial: 'svelte'),
          ),
        ),
      ),
    );
    await openByTap(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(wrapKey.currentState!.value, 'vue');
  });

  testWidgets('web-map Enter selects; Space types when searchable',
      (WidgetTester tester) async {
    final GlobalKey<_HostState> key = GlobalKey<_HostState>();
    await tester.pumpWidget(
      wrapWebKeys(
        Center(
          child: SizedBox(
            width: 320,
            child: _Host(key: key, initial: 'vue'),
          ),
        ),
      ),
    );
    await openByTap(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(key.currentState!.value, 'react');

    await tester.pumpWidget(
      wrapWebKeys(
        Center(
          child: SizedBox(
            width: 320,
            child: _Host(key: key, searchable: true, initial: 'vue'),
          ),
        ),
      ),
    );
    await openByTap(tester);
    expect(key.currentState!.searches, <String>['']);
    await tester.enterText(find.byType(EditableText), ' ');
    await tester.pump();
    expect(popup, findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      contains(' '),
    );
  });

  testWidgets('type-ahead finds solid from s, o, then resets after 600ms',
      (WidgetTester tester) async {
    final GlobalKey<_HostState> key = GlobalKey<_HostState>();
    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 320,
            child: _Host(key: key, initial: 'vue'),
          ),
        ),
      ),
    );
    await openByTap(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(key.currentState!.value, 'solid');

    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 320,
            child: _Host(key: key, initial: 'vue'),
          ),
        ),
      ),
    );
    await openByTap(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(key.currentState!.value, 'vue');
  });

  testWidgets('active row scrolls in a 20-option list; the page does not',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    final ScrollController page = ScrollController();
    addTearDown(page.dispose);
    final List<KunSelectOption<String>> options = <KunSelectOption<String>>[
      for (int i = 0; i < 20; i++)
        KunSelectOption<String>(value: 'o$i', label: 'Option $i'),
    ];
    await tester.pumpWidget(
      wrap(
        SizedBox(
          height: 600,
          child: SingleChildScrollView(
            controller: page,
            child: Column(
              children: <Widget>[
                SizedBox(
                  width: 320,
                  child: _Host(options: options, initial: 'o0'),
                ),
                const SizedBox(height: 1200),
              ],
            ),
          ),
        ),
      ),
    );
    await openByTap(tester);
    final double pageBefore = page.offset;
    for (int i = 0; i < 15; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    expect(page.offset, pageBefore);
    final ScrollableState list = tester.state<ScrollableState>(
      find.descendant(of: popup, matching: find.byType(Scrollable)),
    );
    expect(list.position.pixels, greaterThan(0));
  });

  testWidgets('single choose: onChanged, onSet with options index, then closed',
      (WidgetTester tester) async {
    final GlobalKey<_HostState> key = GlobalKey<_HostState>();
    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 320,
            child: _Host(key: key, searchable: true, initial: 'vue'),
          ),
        ),
      ),
    );
    await openByTap(tester);
    await tester.enterText(find.byType(EditableText), 'so');
    await tester.pump();
    await tester.tap(find.text('Solid'));
    await tester.pumpAndSettle();
    expect(key.currentState!.changed, <String?>['solid']);
    expect(key.currentState!.sets, <(String, int)>[('solid', 2)]);
    expect(popup, findsNothing);
  });

  testWidgets(
      'multiple toggles, stays open, search keeps focus, onSet each time',
      (WidgetTester tester) async {
    final GlobalKey<_HostState> key = GlobalKey<_HostState>();
    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 320,
            child: _Host(
              key: key,
              multiple: true,
              searchable: true,
              initialValues: const <String>['vue'],
            ),
          ),
        ),
      ),
    );
    await openByTap(tester);
    expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue);
    await tester.tap(find.text('React'));
    await tester.pump();
    expect(popup, findsOneWidget);
    expect(key.currentState!.values, <String>['vue', 'react']);
    expect(key.currentState!.sets.last, ('react', 1));
    expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue);
    await tester.tap(find.text('Vue').last);
    await tester.pump();
    expect(key.currentState!.values, <String>['react']);
    expect(key.currentState!.sets.last, ('vue', 0));
  });

  testWidgets('disabled options, chip ×, clear', (WidgetTester tester) async {
    final GlobalKey<_HostState> key = GlobalKey<_HostState>();
    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 360,
            child: _Host(
              key: key,
              multiple: true,
              initialValues: const <String>['vue', 'react'],
              clearable: true,
            ),
          ),
        ),
      ),
    );
    await openByTap(tester);
    await tester.tap(find.text('Angular'));
    await tester.pump();
    expect(key.currentState!.values, <String>['vue', 'react']);
    expect(key.currentState!.sets, isEmpty);
    expect(popup, findsOneWidget);

    await tester.tap(find.byIcon(KunIcons.x).first);
    await tester.pump();
    expect(key.currentState!.values, <String>['react']);
    expect(key.currentState!.sets, isEmpty);
    expect(popup, findsOneWidget);

    await tester.tap(find.byIcon(KunIcons.circleX));
    await tester.pump();
    expect(key.currentState!.values, isEmpty);
    expect(key.currentState!.sets, isEmpty);

    final GlobalKey<_HostState> singleKey = GlobalKey<_HostState>();
    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 320,
            child: _Host(
              key: singleKey,
              initial: 'vue',
              clearable: true,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(KunIcons.circleX));
    await tester.pumpAndSettle();
    expect(singleKey.currentState!.changed, <String?>[null]);
    expect(singleKey.currentState!.sets, isEmpty);
    expect(popup, findsNothing);
  });

  testWidgets('Backspace and Delete on the trigger remove the last or clear',
      (WidgetTester tester) async {
    Future<GlobalKey<_HostState>> focused(_Host Function(Key key) host) async {
      final GlobalKey<_HostState> key = GlobalKey<_HostState>();
      await tester.pumpWidget(
        wrap(Center(child: SizedBox(width: 320, child: host(key)))),
      );
      Focus.of(tester.element(trigger)).requestFocus();
      await tester.pump();
      return key;
    }

    final GlobalKey<_HostState> multi = await focused(
      (Key key) => _Host(
        key: key,
        multiple: true,
        initialValues: const <String>['vue', 'react', 'solid'],
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(multi.currentState!.values, <String>['vue', 'react']);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(multi.currentState!.values, <String>['vue']);
    expect(popup, findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(popup, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(multi.currentState!.values, isEmpty);
    expect(popup, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(multi.currentState!.valuesChanged, hasLength(3));

    final GlobalKey<_HostState> clearable = await focused(
      (Key key) => _Host(key: key, initial: 'vue', clearable: true),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(clearable.currentState!.changed, <String?>[null]);
    expect(clearable.currentState!.value, isNull);

    final GlobalKey<_HostState> plain = await focused(
      (Key key) => _Host(key: key, initial: 'vue'),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(plain.currentState!.changed, isEmpty);
    expect(plain.currentState!.value, 'vue');

    final GlobalKey<_HostState> searching = await focused(
      (Key key) => _Host(
        key: key,
        multiple: true,
        searchable: true,
        initialValues: const <String>['vue', 'react'],
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(Focus.of(tester.element(trigger)).hasPrimaryFocus, isFalse);
    await tester.enterText(find.byType(EditableText), 'so');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(searching.currentState!.values, <String>['vue', 'react']);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      's',
    );
  });

  testWidgets('clear is a labelled button beside the combobox; chip × is not',
      (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final GlobalKey<_HostState> key = GlobalKey<_HostState>();
    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 360,
            child: _Host(
              key: key,
              label: 'Framework',
              multiple: true,
              clearable: true,
              initialValues: const <String>['vue', 'react'],
            ),
          ),
        ),
      ),
    );
    expect(find.byIcon(KunIcons.x), findsNWidgets(2));
    expect(find.byIcon(KunIcons.circleX), findsOneWidget);

    final KunMessages messages = KunMessagesScope.of(tester.element(trigger));
    final SemanticsOwner owner =
        tester.binding.renderViews.first.owner!.semanticsOwner!;
    void collect(SemanticsNode node, List<SemanticsNode> into) {
      into.add(node);
      node.visitChildren((SemanticsNode child) {
        collect(child, into);
        return true;
      });
    }

    final List<SemanticsNode> nodes = <SemanticsNode>[];
    collect(owner.rootSemanticsNode!, nodes);
    final List<String> labels = <String>[
      for (final SemanticsNode n in nodes) n.getSemanticsData().label,
    ];
    expect(labels, isNot(contains(messages.select.removeOption(label: 'Vue'))));
    expect(
      labels,
      isNot(contains(messages.select.removeOption(label: 'React'))),
    );
    final SemanticsNode combo = nodes.singleWhere(
      (SemanticsNode n) =>
          n.getSemanticsData().label == 'Framework' &&
          n.getSemanticsData().value == '2',
    );
    final SemanticsNode clear = nodes.singleWhere(
      (SemanticsNode n) => n.getSemanticsData().label == messages.select.clear,
    );
    final SemanticsData clearData = clear.getSemanticsData();
    expect(clearData.flagsCollection.isButton, isTrue);
    expect(clearData.flagsCollection.isFocused, Tristate.none);
    expect(clearData.hasAction(SemanticsAction.tap), isTrue);
    final List<SemanticsNode> inCombo = <SemanticsNode>[];
    collect(combo, inCombo);
    expect(inCombo, isNot(contains(clear)));
    expect(clear.parent, same(combo.parent));

    final FocusNode node = Focus.of(tester.element(trigger));
    expect(node.hasFocus, isFalse);
    owner.performAction(clear.id, SemanticsAction.tap);
    await tester.pump();
    expect(key.currentState!.valuesChanged, <List<String>>[<String>[]]);
    expect(find.byIcon(KunIcons.circleX), findsNothing);
    expect(node.hasPrimaryFocus, isTrue);
    semantics.dispose();
  });

  testWidgets('clear by pointer: focus to the trigger only while closed',
      (WidgetTester tester) async {
    final FocusHighlightStrategy previous =
        FocusManager.instance.highlightStrategy;
    addTearDown(() {
      FocusManager.instance.highlightStrategy = previous;
    });
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;

    final GlobalKey<_HostState> closed = GlobalKey<_HostState>();
    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 320,
            child: _Host(key: closed, initial: 'vue', clearable: true),
          ),
        ),
      ),
    );
    final FocusNode node = Focus.of(tester.element(trigger));
    expect(node.hasFocus, isFalse);
    await tester.tap(find.byIcon(KunIcons.circleX));
    await tester.pump();
    await tester.pump(KunDefaultTransition.duration);
    expect(closed.currentState!.changed, <String?>[null]);
    expect(popup, findsNothing);
    expect(node.hasPrimaryFocus, isTrue);
    expect(triggerDecoration(tester).boxShadow!.first.spreadRadius, 0);

    final GlobalKey<_HostState> open = GlobalKey<_HostState>();
    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 320,
            child: _Host(
              key: open,
              initial: 'vue',
              clearable: true,
              searchable: true,
            ),
          ),
        ),
      ),
    );
    await openByTap(tester);
    final FocusNode? search = FocusManager.instance.primaryFocus;
    expect(search, isNot(same(Focus.of(tester.element(trigger)))));
    await tester.tap(find.byIcon(KunIcons.circleX));
    await tester.pump();
    expect(open.currentState!.changed, <String?>[null]);
    expect(popup, findsOneWidget);
    expect(FocusManager.instance.primaryFocus, same(search));
  });

  testWidgets('search filtering, manualFilter, debounce, loading, noResult',
      (WidgetTester tester) async {
    final GlobalKey<_HostState> key = GlobalKey<_HostState>();
    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 320,
            child: _Host(key: key, searchable: true),
          ),
        ),
      ),
    );
    await openByTap(tester);
    expect(key.currentState!.searches, <String>['']);
    await tester.enterText(find.byType(EditableText), '  SoL ');
    await tester.pump();
    expect(find.text('Solid'), findsOneWidget);
    expect(find.text('Vue'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(key.currentState!.value, 'solid');
    expect(key.currentState!.sets.last.$2, 2);

    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 320,
            child: _Host(
              key: UniqueKey(),
              searchable: true,
              manualFilter: true,
            ),
          ),
        ),
      ),
    );
    await openByTap(tester);
    await tester.enterText(find.byType(EditableText), 'so');
    await tester.pump();
    expect(find.text('Vue'), findsOneWidget);

    final GlobalKey<_HostState> debounceKey = GlobalKey<_HostState>();
    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 320,
            child: _Host(
              key: debounceKey,
              searchable: true,
              debounce: const Duration(milliseconds: 300),
            ),
          ),
        ),
      ),
    );
    await openByTap(tester);
    debounceKey.currentState!.searches.clear();
    await tester.enterText(find.byType(EditableText), 's');
    await tester.pump();
    await tester.enterText(find.byType(EditableText), 'so');
    await tester.pump();
    expect(find.byType(KunSpinner), findsOneWidget);
    expect(debounceKey.currentState!.searches, isEmpty);
    await tester.pump(const Duration(milliseconds: 300));
    expect(debounceKey.currentState!.searches, <String>['so']);
    expect(find.byType(KunSpinner), findsNothing);

    await tester.enterText(find.byType(EditableText), 'zzz');
    await tester.pump();
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    final int afterClose = debounceKey.currentState!.searches.length;
    await tester.pump(const Duration(milliseconds: 300));
    expect(debounceKey.currentState!.searches.length, afterClose);

    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 320,
            child: _Host(
              key: UniqueKey(),
              searchable: true,
              loading: true,
              loadingText: 'Fetching…',
            ),
          ),
        ),
      ),
    );
    await openByTap(tester);
    expect(find.byType(KunSpinner), findsOneWidget);
    expect(find.text('Fetching…'), findsWidgets);

    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 320,
            child: _Host(
              key: UniqueKey(),
              searchable: true,
              noResultText: 'Nothing here',
              options: const <KunSelectOption<String>>[],
            ),
          ),
        ),
      ),
    );
    await tester.tap(trigger);
    await tester.pump();
    await tester.pump(KunDurations.base);
    expect(find.text('Nothing here'), findsOneWidget);
  });

  testWidgets('IME composing does not filter or search until commit',
      (WidgetTester tester) async {
    final GlobalKey<_HostState> key = GlobalKey<_HostState>();
    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 320,
            child: _Host(key: key, searchable: true, initial: 'vue'),
          ),
        ),
      ),
    );
    await openByTap(tester);
    await tester.tap(find.byType(EditableText));
    await tester.pump();
    key.currentState!.searches.clear();
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'ni',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ),
    );
    await tester.pump();
    expect(key.currentState!.searches, isEmpty);
    expect(find.text('Vue'), findsWidgets);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(popup, findsOneWidget);
    expect(key.currentState!.changed, isEmpty);

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '你',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump();
    expect(key.currentState!.searches, <String>['你']);
  });

  testWidgets('geometry at 800×600: below, flip, shift, caps, widths, follow',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(
      wrap(
        const SizedBox(
          width: 800,
          height: 600,
          child: Stack(
            children: <Widget>[
              Positioned(
                left: 16,
                top: 16,
                width: 240,
                child: _Host(initial: 'vue'),
              ),
            ],
          ),
        ),
      ),
    );
    await openByTap(tester);
    final Rect triggerRect = tester.getRect(trigger);
    final Rect popupRect = tester.getRect(popup);
    expect(popupRect.left, closeTo(triggerRect.left, 0.5));
    expect(popupRect.top, closeTo(triggerRect.bottom + 4, 0.5));
    expect(popupRect.width, closeTo(triggerRect.width, 0.5));

    await tester.pumpWidget(
      wrap(
        Align(
          alignment: Alignment.bottomLeft,
          child: SizedBox(
            width: 240,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: _Host(key: UniqueKey(), initial: 'vue'),
            ),
          ),
        ),
      ),
    );
    await openByTap(tester);
    final Rect lowTrigger = tester.getRect(trigger);
    final Rect flipped = tester.getRect(popup);
    expect(flipped.bottom, closeTo(lowTrigger.top - 4, 1));

    await tester.pumpWidget(
      wrap(
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 80,
            child: _Host(
              key: UniqueKey(),
              initial: 'vue',
              popupWidth: const KunSelectPopupWidth.fixed(300),
            ),
          ),
        ),
      ),
    );
    await openByTap(tester);
    final Rect shifted = tester.getRect(popup);
    expect(shifted.width, closeTo(300, 0.5));
    expect(shifted.right, closeTo(800 - 8, 1));

    final List<KunSelectOption<String>> many = <KunSelectOption<String>>[
      for (int i = 0; i < 20; i++)
        KunSelectOption<String>(value: 'o$i', label: 'Option $i'),
    ];
    await tester.pumpWidget(
      wrap(
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 240,
            child: _Host(key: UniqueKey(), options: many, initial: 'o0'),
          ),
        ),
      ),
    );
    await openByTap(tester);
    expect(tester.getRect(popup).height, lessThanOrEqualTo(280));

    await tester.pumpWidget(
      wrap(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            child: _Host(
              key: UniqueKey(),
              initial: 'vue',
              popupWidth: KunSelectPopupWidth.auto,
              options: const <KunSelectOption<String>>[
                KunSelectOption<String>(
                  value: 'long',
                  label: 'A remarkably long option label',
                ),
                KunSelectOption<String>(value: 'vue', label: 'Vue'),
              ],
            ),
          ),
        ),
      ),
    );
    await openByTap(tester);
    expect(tester.getRect(popup).width,
        greaterThan(tester.getRect(trigger).width));

    setView(tester, const Size(360, 600));
    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 200,
            child: _Host(
              key: UniqueKey(),
              initial: 'vue',
              popupWidth: const KunSelectPopupWidth.fixed(700),
            ),
          ),
        ),
      ),
    );
    await openByTap(tester);
    expect(tester.getRect(popup).width, closeTo(344, 0.5));

    setView(tester, const Size(800, 600));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      wrap(
        Align(
          alignment: const Alignment(0, 0.2),
          child: SizedBox(
            width: 240,
            child: _Host(key: UniqueKey(), initial: 'vue'),
          ),
        ),
      ),
    );
    await openByTap(tester);
    expect(tester.getRect(popup).bottom,
        lessThanOrEqualTo(tester.getRect(trigger).top + 1));

    tester.view.viewInsets = FakeViewPadding.zero;
    final ScrollController page = ScrollController();
    addTearDown(page.dispose);
    await tester.pumpWidget(
      wrap(
        SizedBox(
          height: 600,
          child: SingleChildScrollView(
            controller: page,
            child: Column(
              children: <Widget>[
                const SizedBox(height: 120),
                SizedBox(
                  width: 240,
                  child: _Host(key: UniqueKey(), initial: 'vue'),
                ),
                const SizedBox(height: 800),
              ],
            ),
          ),
        ),
      ),
    );
    await openByTap(tester);
    final double gap =
        tester.getRect(popup).top - tester.getRect(trigger).bottom;
    page.jumpTo(40);
    await tester.pump();
    expect(
      tester.getRect(popup).top - tester.getRect(trigger).bottom,
      closeTo(gap, 1),
    );
  });

  testWidgets('styling: fill, border, radius, heights, chips, copy',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        const Center(
          child: SizedBox(width: 320, child: _Host(label: 'Framework')),
        ),
      ),
    );
    expect(triggerDecoration(tester).color, KunColors.light.content1);
    expect(
      (triggerDecoration(tester).border! as Border).top.color,
      KunColors.light.border,
    );
    expect(
      triggerDecoration(tester).borderRadius,
      BorderRadius.circular(KunRadius.md),
    );
    expect(
      tester.getSize(trigger).height,
      KunControlMetrics.of(KunUISize.md).square,
    );

    await tester.pumpWidget(
      wrap(
        const Center(
          child: SizedBox(
            width: 320,
            child: _Host(error: 'Required', placeholder: '请选择'),
          ),
        ),
      ),
    );
    expect(
      (triggerDecoration(tester).border! as Border).top.color,
      KunColors.light.danger.shade300,
    );
    expect(resolvedOf(tester, 'Required').color, KunColors.light.danger.solid);

    for (final KunUISize size in KunUISize.values) {
      await tester.pumpWidget(
        wrap(
          Center(
            child: SizedBox(
              width: 320,
              child: _Host(size: size, initial: 'vue'),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(trigger).height,
        KunControlMetrics.of(size).square,
        reason: size.name,
      );
    }

    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 320,
            child: _Host(
              key: UniqueKey(),
              rounded: KunUIRounded.full,
              initial: 'vue',
            ),
          ),
        ),
      ),
    );
    expect(
      triggerDecoration(tester).borderRadius,
      BorderRadius.circular(KunRadius.full),
    );
    await openByTap(tester);
    final DecoratedBox panel = tester.widget<DecoratedBox>(popup);
    expect(
      (panel.decoration as BoxDecoration).borderRadius,
      BorderRadius.circular(KunRadius.lg),
    );

    await tester.pumpWidget(
      wrap(
        const Center(
          child: SizedBox(
            width: 360,
            child: _Host(
              multiple: true,
              initialValues: <String>['vue'],
              label: 'Frameworks',
              description: 'Pick some',
            ),
          ),
        ),
      ),
    );
    expect(resolvedOf(tester, 'Frameworks').fontWeight, KunFontWeights.medium);
    expect(resolvedOf(tester, 'Frameworks').color,
        KunColors.light.neutral.shade700);
    expect(resolvedOf(tester, 'Pick some').color,
        KunColors.light.neutral.shade500);
    expect(find.text('Vue'), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        const Align(
          alignment: Alignment.topLeft,
          child: _Host(fullWidth: false, initial: 'vue', label: 'L'),
        ),
      ),
    );
    expect(
        tester
            .getSize(find.byType(KunSelect<String, KunSelectOption<String>>))
            .width,
        lessThan(400));

    await tester.pumpWidget(
      wrap(
        const Center(
          child: SizedBox(width: 320, child: _Host(initial: 'vue')),
        ),
      ),
    );
    await openByTap(tester);
    expect(find.byIcon(KunIcons.check), findsOneWidget);
    final DecoratedBox active = tester.widget<DecoratedBox>(
      find
          .descendant(of: optionAt(0), matching: find.byType(DecoratedBox))
          .first,
    );
    expect(
      (active.decoration as BoxDecoration).color,
      KunColors.light.neutral.shade100
          .withValues(alpha: KunColors.globalOpacity),
    );
  });

  testWidgets('focus ring is keyboard-only and danger with error',
      (WidgetTester tester) async {
    final FocusHighlightStrategy previous =
        FocusManager.instance.highlightStrategy;
    addTearDown(() {
      FocusManager.instance.highlightStrategy = previous;
    });

    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    await tester.pumpWidget(
      wrap(
        const Center(
          child: SizedBox(width: 320, child: _Host()),
        ),
      ),
    );
    Focus.of(tester.element(trigger)).requestFocus();
    await tester.pump();
    await tester.pump(KunDefaultTransition.duration);
    expect(triggerDecoration(tester).boxShadow!.first.spreadRadius, 0);

    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    await tester.pump();
    await tester.pump(KunDefaultTransition.duration);
    expect(triggerDecoration(tester).boxShadow!.first.spreadRadius, 2);
    expect(
      triggerDecoration(tester).boxShadow!.first.color,
      KunColors.light.neutral.solid.withValues(alpha: 0.5),
    );

    await tester.pumpWidget(
      wrap(
        const Center(
          child: SizedBox(
            width: 320,
            child: _Host(error: 'Required'),
          ),
        ),
      ),
    );
    Focus.of(tester.element(trigger)).requestFocus();
    await tester.pump();
    await tester.pump(KunDefaultTransition.duration);
    expect(
      triggerDecoration(tester).boxShadow!.first.color,
      KunColors.light.danger.solid.withValues(alpha: 0.5),
    );
  });

  testWidgets('transitions: scale origin, close delay, reduced motion, chevron',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        const Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: 240, child: _Host(initial: 'vue')),
        ),
      ),
    );
    await tester.tap(trigger);
    await tester.pump();
    await tester.pump(KunDurations.base ~/ 2);
    final FadeTransition fade = tester.widget<FadeTransition>(popupFade);
    final Transform scale = tester.widget<Transform>(popupScale);
    expect(fade.opacity.value, greaterThan(0));
    expect(fade.opacity.value, lessThan(1));
    expect(scale.transform.storage[0], greaterThan(0.95));
    expect(scale.transform.storage[0], lessThan(1));
    expect(scale.alignment, Alignment.topLeft);
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      wrap(
        Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: 240,
            child: _Host(key: UniqueKey(), initial: 'vue'),
          ),
        ),
      ),
    );
    await tester.tap(trigger);
    await tester.pump();
    await tester.pump();
    await tester.pump(KunDurations.base ~/ 2);
    expect(
      tester.widget<Transform>(popupScale).alignment,
      Alignment.bottomLeft,
    );
    await tester.pumpAndSettle();

    await tester.tap(trigger);
    await tester.pump();
    await tester.pump(KunDurations.exit ~/ 2);
    expect(popup, findsOneWidget);
    await tester.pumpAndSettle();
    expect(popup, findsNothing);

    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 240,
            child: _Host(key: UniqueKey(), initial: 'vue'),
          ),
        ),
        wrapHome: (Widget child) {
          return MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: child,
          );
        },
      ),
    );
    await tester.tap(trigger);
    await tester.pump();
    expect(tester.widget<FadeTransition>(popupFade).opacity.value, 1);
    expect(tester.widget<Transform>(popupScale).transform.storage[0], 1);
    await tester.tap(trigger);
    await tester.pump();
    await tester.pump();
    expect(popup, findsNothing);

    await tester.pumpWidget(
      wrap(
        const Center(child: SizedBox(width: 240, child: _Host(initial: 'vue'))),
      ),
    );
    expect(
      tester.widget<AnimatedRotation>(chevron).turns,
      0,
    );
    await openByTap(tester);
    expect(
      tester.widget<AnimatedRotation>(chevron).turns,
      0.5,
    );
  });

  testWidgets('inside a KunModal: popup above, Escape then modal, Tab stays',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const _ModalSelectHost()));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey<String>('KunModal.panel')), findsOneWidget);
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    expect(popup, findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    await tester.enterText(find.byType(EditableText), 're');
    await tester.pump();
    expect(find.text('React'), findsOneWidget);

    await tester.tap(find.text('React'));
    await tester.pumpAndSettle();
    expect(popup, findsNothing);
    expect(
        find.byKey(const ValueKey<String>('KunModal.panel')), findsOneWidget);

    await tester.tap(trigger);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(popup, findsNothing);
    expect(
        find.byKey(const ValueKey<String>('KunModal.panel')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('KunModal.panel')), findsNothing);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    expect(popup, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(popup, findsNothing);
    expect(
        find.byKey(const ValueKey<String>('KunModal.panel')), findsOneWidget);
    expect(Focus.of(tester.element(trigger)).hasFocus, isTrue);
  });

  testWidgets('semantics: trigger, list, items, no error',
      (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        const Center(
          child: SizedBox(
            width: 320,
            child: _Host(initial: 'vue', label: 'Framework'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    SemanticsNode? combo;
    void walk(SemanticsNode node) {
      final SemanticsData data = node.getSemanticsData();
      if (data.label == 'Framework' && data.value == 'Vue') {
        combo = node;
      }
      node.visitChildren((SemanticsNode child) {
        walk(child);
        return true;
      });
    }

    walk(tester
        .binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
    expect(combo, isNotNull);
    expect(
        combo!.getSemanticsData().flagsCollection.isExpanded, Tristate.isFalse);

    await openByTap(tester);
    combo = null;
    walk(tester
        .binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
    expect(combo, isNotNull);
    expect(
        combo!.getSemanticsData().flagsCollection.isExpanded, Tristate.isTrue);

    SemanticsNode? list;
    final List<SemanticsNode> items = <SemanticsNode>[];
    void walkOpen(SemanticsNode node) {
      final SemanticsData data = node.getSemanticsData();
      if (data.role == SemanticsRole.list) {
        list = node;
      }
      if (data.role == SemanticsRole.listItem) {
        items.add(node);
      }
      node.visitChildren((SemanticsNode child) {
        walkOpen(child);
        return true;
      });
    }

    walkOpen(tester
        .binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
    expect(list, isNotNull);
    expect(items.length, greaterThanOrEqualTo(5));
    expect(
      items.any((SemanticsNode n) =>
          n.getSemanticsData().label.contains('Vue') &&
          n.getSemanticsData().flagsCollection.isSelected == Tristate.isTrue),
      isTrue,
    );
    expect(
      items.any((SemanticsNode n) =>
          n.getSemanticsData().label.contains('Angular') &&
          n.getSemanticsData().flagsCollection.isEnabled == Tristate.isFalse),
      isTrue,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 320,
            child: _Host(
              key: UniqueKey(),
              semanticLabel: 'Pick a framework',
            ),
          ),
        ),
      ),
    );
    SemanticsNode? named;
    void walkNamed(SemanticsNode node) {
      if (node.getSemanticsData().label == 'Pick a framework') {
        named = node;
      }
      node.visitChildren((SemanticsNode child) {
        walkNamed(child);
        return true;
      });
    }

    walkNamed(tester
        .binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
    expect(named, isNotNull);

    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 320,
            child: _Host(key: UniqueKey()),
          ),
        ),
      ),
    );
    SemanticsNode? fallback;
    void walkFallback(SemanticsNode node) {
      if (node.getSemanticsData().label == 'select') {
        fallback = node;
      }
      node.visitChildren((SemanticsNode child) {
        walkFallback(child);
        return true;
      });
    }

    walkFallback(tester
        .binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
    expect(fallback, isNotNull);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets(
      'optionBuilder receives subclass and LayoutBuilder works with auto',
      (WidgetTester tester) async {
    final List<String> seen = <String>[];
    const List<_NamedOption> options = <_NamedOption>[
      _NamedOption(value: 'kun', label: 'Kun', description: '前端'),
      _NamedOption(value: 'moe', label: 'Moe', description: '设计'),
    ];
    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 320,
            child: KunSelect<String, _NamedOption>(
              options: options,
              value: 'kun',
              onChanged: (_) {},
              optionBuilder: (
                BuildContext context,
                _NamedOption option,
                int index,
                bool active,
                bool selected,
              ) {
                seen.add('${option.description} $index $active $selected');
                return Text('${option.label} ${option.description}');
              },
            ),
          ),
        ),
      ),
    );
    await openByTap(tester);
    expect(find.text('Kun 前端'), findsOneWidget);
    expect(
        seen.any((String s) => s.contains('前端') && s.contains('true')), isTrue);

    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 200,
            child: KunSelect<String, KunSelectOption<String>>(
              options: frameworks,
              value: 'vue',
              onChanged: (_) {},
              popupWidth: KunSelectPopupWidth.auto,
              optionBuilder: (
                BuildContext context,
                KunSelectOption<String> option,
                int index,
                bool active,
                bool selected,
              ) {
                return LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    return Text('${option.label}:${constraints.maxWidth}');
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
    await openByTap(tester);
    expect(tester.takeException(), isNull);
    expect(popup, findsOneWidget);
  });

  testWidgets(
      'disposal while open with a pending search: no error, no late emit',
      (WidgetTester tester) async {
    final List<String> searches = <String>[];
    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 320,
            child: _Host(
              searchable: true,
              debounce: const Duration(milliseconds: 300),
              onSearch: searches.add,
            ),
          ),
        ),
      ),
    );
    await openByTap(tester);
    searches.clear();
    await tester.enterText(find.byType(EditableText), 'so');
    await tester.pump();
    await tester.pumpWidget(wrap(const SizedBox.shrink()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(searches, isEmpty);
  });

  testWidgets('flip uses laid-out height, not the 280 cap',
      (WidgetTester tester) async {
    const List<KunSelectOption<String>> two = <KunSelectOption<String>>[
      KunSelectOption<String>(value: 'a', label: 'A'),
      KunSelectOption<String>(value: 'b', label: 'B'),
    ];
    final List<KunSelectOption<String>> many = <KunSelectOption<String>>[
      for (int i = 0; i < 20; i++)
        KunSelectOption<String>(value: 'o$i', label: 'Option $i'),
    ];

    Future<void> pumpPlaced({
      required Size view,
      required double top,
      required List<KunSelectOption<String>> options,
    }) async {
      setView(tester, view);
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: view.width,
            height: view.height,
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: 16,
                  top: top,
                  width: 240,
                  child: _Host(key: UniqueKey(), options: options),
                ),
              ],
            ),
          ),
        ),
      );
    }

    await pumpPlaced(
      view: const Size(800, 800),
      top: 16,
      options: two,
    );
    final double triggerH = tester.getRect(trigger).height;
    await openByTap(tester);
    final double h = tester.getRect(popup).height;
    expect(h, lessThan(150));

    final double fitViewH = 400 + 4 + triggerH + 4 + 150;
    await pumpPlaced(view: Size(800, fitViewH), top: 404, options: two);
    await openByTap(tester);
    final Rect fitTrigger = tester.getRect(trigger);
    final Rect fitPopup = tester.getRect(popup);
    final double fitBelow = fitViewH - fitTrigger.bottom - 4;
    final double fitAbove = fitTrigger.top - 4;
    expect(fitBelow, closeTo(150, 1));
    expect(fitAbove, closeTo(400, 1));
    expect(fitPopup.top, closeTo(fitTrigger.bottom + 4, 1));

    final double onlyAboveViewH = 400 + 4 + triggerH + 4 + (h - 9);
    await pumpPlaced(
      view: Size(800, onlyAboveViewH),
      top: 404,
      options: two,
    );
    await openByTap(tester);
    final Rect onlyTrigger = tester.getRect(trigger);
    final Rect onlyPopup = tester.getRect(popup);
    expect(h, greaterThan((onlyAboveViewH - onlyTrigger.bottom - 4) - 8));
    expect(onlyPopup.bottom, closeTo(onlyTrigger.top - 4, 1));

    await pumpPlaced(
      view: Size(800, 400 + 4 + triggerH + 4 + h),
      top: 404,
      options: two,
    );
    await openByTap(tester);
    final Rect bandTrigger = tester.getRect(trigger);
    final Rect bandPopup = tester.getRect(popup);
    final double bandBelow =
        (400 + 4 + triggerH + 4 + h) - bandTrigger.bottom - 4;
    expect(bandBelow - 8, lessThan(h));
    expect(h, lessThanOrEqualTo(bandBelow));
    expect(bandPopup.bottom, closeTo(bandTrigger.top - 4, 1));

    const Size neitherView = Size(800, 200);
    const double neitherTop = 90;
    await pumpPlaced(view: neitherView, top: neitherTop, options: many);
    await openByTap(tester);
    final Rect neitherTrigger = tester.getRect(trigger);
    final Rect neitherPopup = tester.getRect(popup);
    final double neitherBelow = 200 - neitherTrigger.bottom - 4;
    final double neitherAbove = neitherTrigger.top - 4;
    final double larger =
        neitherAbove > neitherBelow ? neitherAbove : neitherBelow;
    expect(neitherPopup.height, closeTo(larger - 8, 1));
    if (neitherAbove > neitherBelow) {
      expect(neitherPopup.bottom, closeTo(neitherTrigger.top - 4, 1));
    } else {
      expect(neitherPopup.top, closeTo(neitherTrigger.bottom + 4, 1));
    }
  });

  testWidgets('auto popup width: trigger floor, selected check, search floor',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    const List<KunSelectOption<String>> shorts = <KunSelectOption<String>>[
      KunSelectOption<String>(value: 'a', label: 'A'),
      KunSelectOption<String>(value: 'b', label: 'B'),
      KunSelectOption<String>(value: 'c', label: 'C'),
    ];
    await tester.pumpWidget(
      wrap(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 80,
            child: _Host(
              key: UniqueKey(),
              options: shorts,
              popupWidth: KunSelectPopupWidth.auto,
            ),
          ),
        ),
      ),
    );
    await openByTap(tester);
    expect(tester.getRect(popup).width, closeTo(80, 0.5));
    expect(tester.getRect(trigger).width, closeTo(80, 0.5));

    const List<KunSelectOption<String>> longs = <KunSelectOption<String>>[
      KunSelectOption<String>(value: 'a', label: 'Short'),
      KunSelectOption<String>(
        value: 'b',
        label: 'A remarkably long option label',
      ),
      KunSelectOption<String>(value: 'c', label: 'Mid'),
    ];
    await tester.pumpWidget(
      wrap(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 80,
            child: _Host(
              key: UniqueKey(),
              options: longs,
              popupWidth: KunSelectPopupWidth.auto,
            ),
          ),
        ),
      ),
    );
    await openByTap(tester);
    final double unselected = tester.getRect(popup).width;
    expect(unselected, greaterThan(80));
    await tester.tap(find.text('A remarkably long option label'));
    await tester.pumpAndSettle();
    await openByTap(tester);
    final double em = MediaQuery.textScalerOf(tester.element(popup))
        .scale(KunText.sm.fontSize!);
    expect(
      tester.getRect(popup).width,
      closeTo(unselected + KunSpacing.unit * 2 + em, 0.5),
    );

    await tester.pumpWidget(
      wrap(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 80,
            child: _Host(
              key: UniqueKey(),
              options: shorts,
              searchable: true,
              popupWidth: KunSelectPopupWidth.auto,
            ),
          ),
        ),
      ),
    );
    await openByTap(tester);
    final TextPainter zero = TextPainter(
      text: const TextSpan(text: '0', style: KunText.sm),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(tester.element(popup)),
    )..layout();
    final double searchFloor = 20 * zero.width +
        KunSpacing.unit * 2.5 * 2 +
        2 +
        KunSpacing.unit * 1 * 2;
    zero.dispose();
    expect(
      tester.getRect(popup).width,
      greaterThanOrEqualTo(searchFloor + KunSpacing.unit * 1 * 2 - 0.5),
    );
  });

  testWidgets('trigger ring follows focus-visible, not traditional-as-keyboard',
      (WidgetTester tester) async {
    final FocusHighlightStrategy previous =
        FocusManager.instance.highlightStrategy;
    addTearDown(() {
      FocusManager.instance.highlightStrategy = previous;
    });
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;

    await tester.pumpWidget(
      wrap(
        const Center(child: SizedBox(width: 320, child: _Host())),
      ),
    );
    await openByTap(tester);
    await tester.pump(KunDefaultTransition.duration);
    expect(triggerDecoration(tester).boxShadow!.first.spreadRadius, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(popup, findsNothing);
    expect(Focus.of(tester.element(trigger)).hasFocus, isTrue);
    expect(triggerDecoration(tester).boxShadow!.first.spreadRadius, 2);

    await openByTap(tester);
    await tester.tap(find.text('React'));
    await tester.pumpAndSettle();
    expect(popup, findsNothing);
    expect(Focus.of(tester.element(trigger)).hasFocus, isTrue);
    expect(triggerDecoration(tester).boxShadow!.first.spreadRadius, 0);

    await openByTap(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(popup, findsNothing);
    expect(Focus.of(tester.element(trigger)).hasFocus, isTrue);
    expect(triggerDecoration(tester).boxShadow!.first.spreadRadius, 2);

    await tester.pumpWidget(
      wrap(
        const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Focus(
                autofocus: true,
                child: SizedBox(
                  key: ValueKey<String>('other'),
                  width: 24,
                  height: 24,
                ),
              ),
              SizedBox(width: 320, child: _Host()),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      Focus.of(tester.element(find.byKey(const ValueKey<String>('other'))))
          .hasFocus,
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.pump(KunDefaultTransition.duration);
    expect(Focus.of(tester.element(trigger)).hasFocus, isTrue);
    expect(triggerDecoration(tester).boxShadow!.first.spreadRadius, 2);
  });

  testWidgets('trigger focused semantics update even without a ring',
      (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final FocusHighlightStrategy previous =
        FocusManager.instance.highlightStrategy;
    addTearDown(() {
      FocusManager.instance.highlightStrategy = previous;
    });
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;

    await tester.pumpWidget(
      wrap(
        const Center(
          child: SizedBox(
            width: 320,
            child: _Host(label: 'Framework'),
          ),
        ),
      ),
    );

    SemanticsNode? combo;
    void walk(SemanticsNode node) {
      final SemanticsData data = node.getSemanticsData();
      if (data.label == 'Framework') {
        combo = node;
      }
      node.visitChildren((SemanticsNode child) {
        walk(child);
        return true;
      });
    }

    walk(tester
        .binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
    expect(combo, isNotNull);
    expect(
        combo!.getSemanticsData().flagsCollection.isFocused, Tristate.isFalse);

    Focus.of(tester.element(trigger)).requestFocus();
    await tester.pump();
    await tester.pump(KunDefaultTransition.duration);
    expect(triggerDecoration(tester).boxShadow!.first.spreadRadius, 0);

    combo = null;
    walk(tester
        .binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
    expect(combo, isNotNull);
    expect(
        combo!.getSemanticsData().flagsCollection.isFocused, Tristate.isTrue);
    semantics.dispose();
  });

  testWidgets('semantics tap and focus actions focus the trigger',
      (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        const Center(
          child: SizedBox(
            width: 320,
            child: _Host(initial: 'vue', label: 'Framework'),
          ),
        ),
      ),
    );
    final SemanticsOwner owner =
        tester.binding.renderViews.first.owner!.semanticsOwner!;
    int comboId() {
      int? id;
      void walk(SemanticsNode node) {
        final SemanticsData data = node.getSemanticsData();
        if (data.label == 'Framework' && data.value == 'Vue') {
          id = node.id;
        }
        node.visitChildren((SemanticsNode child) {
          walk(child);
          return true;
        });
      }

      walk(owner.rootSemanticsNode!);
      return id!;
    }

    final FocusNode node = Focus.of(tester.element(trigger));
    owner.performAction(comboId(), SemanticsAction.tap);
    await tester.pumpAndSettle();
    expect(popup, findsOneWidget);
    expect(node.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(popup, findsNothing);
    node.unfocus();
    await tester.pump();
    expect(node.hasFocus, isFalse);

    owner.performAction(comboId(), SemanticsAction.focus);
    await tester.pump();
    expect(node.hasFocus, isTrue);
    semantics.dispose();
  });
}

class _ModalSelectHost extends StatefulWidget {
  const _ModalSelectHost();

  @override
  State<_ModalSelectHost> createState() => _ModalSelectHostState();
}

class _ModalSelectHostState extends State<_ModalSelectHost> {
  bool open = false;
  String? value = 'vue';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        KunButton(
          onPressed: () => setState(() => open = true),
          child: const Text('Open'),
        ),
        KunModal(
          value: open,
          onChanged: (bool next) => setState(() => open = next),
          title: 'Form',
          child: SizedBox(
            width: 320,
            child: KunSelect<String, KunSelectOption<String>>(
              options: frameworks,
              value: value,
              onChanged: (String? next) => setState(() => value = next),
              searchable: true,
            ),
          ),
        ),
      ],
    );
  }
}
