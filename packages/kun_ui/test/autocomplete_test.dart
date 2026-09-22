import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';
import 'package:kun_ui/src/foundation/dismiss_layers.dart';

const List<KunAutocompleteOption> frameworks = <KunAutocompleteOption>[
  KunAutocompleteOption(value: 'vue', label: 'Vue'),
  KunAutocompleteOption(value: 'react', label: 'React'),
  KunAutocompleteOption(value: 'svelte', label: 'Svelte'),
  KunAutocompleteOption(value: 'angular', label: 'Angular', disabled: true),
];

Finder get list => find.byKey(const ValueKey<String>('KunAutocomplete.list'));
Finder row(String value) =>
    find.byKey(ValueKey<String>('KunAutocomplete.option.$value'));

Widget wrap(Widget child) => KunTheme(
      data: KunThemeData.light(),
      child: WidgetsApp(
        color: KunColors.black,
        debugShowCheckedModeBanner: false,
        home: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(width: 320, child: child),
          ),
        ),
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

void setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// A harness that owns the text, as an application does.
class Host extends StatefulWidget {
  const Host({
    this.options = frameworks,
    this.allowCustomValue = true,
    this.clearable = false,
    this.manualFilter = false,
    this.loading = false,
    this.debounce = Duration.zero,
    this.onSearch,
    this.onSelected,
    super.key,
  });

  final List<KunAutocompleteOption> options;
  final bool allowCustomValue;
  final bool clearable;
  final bool manualFilter;
  final bool loading;
  final Duration debounce;
  final ValueChanged<String>? onSearch;
  final ValueChanged<KunAutocompleteOption>? onSelected;

  @override
  State<Host> createState() => HostState();
}

class HostState extends State<Host> {
  String value = '';

  @override
  Widget build(BuildContext context) {
    return KunAutocomplete<KunAutocompleteOption>(
      options: widget.options,
      value: value,
      allowCustomValue: widget.allowCustomValue,
      clearable: widget.clearable,
      manualFilter: widget.manualFilter,
      loading: widget.loading,
      debounce: widget.debounce,
      label: 'Framework',
      onChanged: (String v) => setState(() => value = v),
      onSearch: widget.onSearch,
      onSelected: widget.onSelected,
    );
  }
}

HostState hostOf(WidgetTester tester) =>
    tester.state<HostState>(find.byType(Host));

Future<void> focusField(WidgetTester tester) async {
  await tester.tap(find.byType(EditableText));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('focusing the field opens the whole list', (tester) async {
    setView(tester, const Size(500, 800));
    await tester.pumpWidget(wrap(const Host()));

    expect(list, findsNothing);
    await focusField(tester);
    expect(list, findsOneWidget);
    for (final KunAutocompleteOption option in frameworks) {
      expect(row(option.value), findsOneWidget);
    }
  });

  testWidgets('typing filters the list and reports the text', (tester) async {
    setView(tester, const Size(500, 800));
    final List<String> searched = <String>[];
    await tester.pumpWidget(
      wrap(Host(onSearch: searched.add)),
    );

    await focusField(tester);
    await tester.enterText(find.byType(EditableText), 'v');
    await tester.pumpAndSettle();

    expect(hostOf(tester).value, 'v');
    expect(searched, <String>['v']);
    // A substring match, not a prefix one: Svelte matches a 'v' too.
    expect(row('vue'), findsOneWidget);
    expect(row('svelte'), findsOneWidget);
    expect(row('react'), findsNothing);
  });

  testWidgets('manualFilter leaves the list alone and still searches',
      (tester) async {
    setView(tester, const Size(500, 800));
    final List<String> searched = <String>[];
    await tester.pumpWidget(
      wrap(Host(manualFilter: true, onSearch: searched.add)),
    );

    await focusField(tester);
    await tester.enterText(find.byType(EditableText), 'zzz');
    await tester.pumpAndSettle();

    expect(searched, <String>['zzz']);
    expect(row('react'), findsOneWidget);
  });

  testWidgets('a tap commits the option, fills the field and closes',
      (tester) async {
    setView(tester, const Size(500, 800));
    KunAutocompleteOption? picked;
    await tester.pumpWidget(
      wrap(Host(onSelected: (KunAutocompleteOption o) => picked = o)),
    );

    await focusField(tester);
    await tester.tap(row('svelte'));
    await tester.pumpAndSettle();

    expect(picked?.value, 'svelte');
    expect(hostOf(tester).value, 'Svelte');
    expect(list, findsNothing);
    expect(KunDismissLayers.debugLayers, isEmpty);
  });

  testWidgets('a disabled option commits nothing', (tester) async {
    setView(tester, const Size(500, 800));
    KunAutocompleteOption? picked;
    await tester.pumpWidget(
      wrap(Host(onSelected: (KunAutocompleteOption o) => picked = o)),
    );

    await focusField(tester);
    await tester.tap(row('angular'));
    await tester.pumpAndSettle();

    expect(picked, isNull);
    expect(list, findsOneWidget);
  });

  testWidgets('the arrow keys move and Enter commits, skipping disabled',
      (tester) async {
    setView(tester, const Size(500, 800));
    KunAutocompleteOption? picked;
    await tester.pumpWidget(
      wrap(Host(onSelected: (KunAutocompleteOption o) => picked = o)),
    );

    await focusField(tester);
    // Opens highlighting the first enabled option; two downs reach Svelte.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(picked?.value, 'svelte');
    expect(hostOf(tester).value, 'Svelte');
  });

  testWidgets('Escape closes it and leaves the text alone', (tester) async {
    setView(tester, const Size(500, 800));
    await tester.pumpWidget(wrap(const Host()));

    await focusField(tester);
    await tester.enterText(find.byType(EditableText), 'vu');
    await tester.pumpAndSettle();
    expect(list, findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(list, findsNothing);
    expect(hostOf(tester).value, 'vu');
  });

  testWidgets('a back gesture closes the list instead of the page',
      (tester) async {
    setView(tester, const Size(500, 800));
    await tester.pumpWidget(wrap(const Host()));

    await focusField(tester);
    expect(list, findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(list, findsNothing);
    expect(find.byType(EditableText), findsOneWidget);
    expect(KunDismissLayers.debugLayers, isEmpty);
  });

  testWidgets('no match shows the locale line, not an empty panel',
      (tester) async {
    setView(tester, const Size(500, 800));
    await tester.pumpWidget(wrap(const Host()));

    await focusField(tester);
    await tester.enterText(find.byType(EditableText), 'zzz');
    await tester.pumpAndSettle();

    expect(find.text(KunMessages.zhCN.autocomplete.noResult), findsOneWidget);
  });

  testWidgets('loading shows the spinner instead of the no-result line',
      (tester) async {
    setView(tester, const Size(500, 800));
    await tester.pumpWidget(wrap(const Host(loading: true)));

    // Not pumpAndSettle anywhere here: the spinner never stops, so settling
    // would wait for an animation that has no end.
    await tester.tap(find.byType(EditableText));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(EditableText), 'zzz');
    await tester.pump();

    expect(find.byType(KunSpinner), findsOneWidget);
    expect(find.text(KunMessages.zhCN.autocomplete.noResult), findsNothing);
  });

  testWidgets('debounce holds the search and shows the spinner meanwhile',
      (tester) async {
    setView(tester, const Size(500, 800));
    final List<String> searched = <String>[];
    await tester.pumpWidget(
      wrap(
        Host(
          debounce: const Duration(milliseconds: 300),
          onSearch: searched.add,
        ),
      ),
    );

    await focusField(tester);
    await tester.enterText(find.byType(EditableText), 'v');
    await tester.pump();
    expect(searched, isEmpty);
    // A pending search must not read as "no matches" either.
    expect(find.byType(KunSpinner), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(searched, <String>['v']);
  });

  testWidgets('allowCustomValue false clears text that matches nothing',
      (tester) async {
    setView(tester, const Size(500, 800));
    await tester.pumpWidget(
      wrap(const Host(allowCustomValue: false)),
    );

    await focusField(tester);
    await tester.enterText(find.byType(EditableText), 'nonsense');
    await tester.pumpAndSettle();

    // Losing focus starts the grace the web defers by, so a tap on an option
    // still commits before the text is judged.
    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 150));
    expect(hostOf(tester).value, '');
  });

  testWidgets('allowCustomValue keeps text that matches nothing',
      (tester) async {
    setView(tester, const Size(500, 800));
    await tester.pumpWidget(wrap(const Host()));

    await focusField(tester);
    await tester.enterText(find.byType(EditableText), 'nonsense');
    await tester.pumpAndSettle();

    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 150));
    expect(hostOf(tester).value, 'nonsense');
  });

  testWidgets('the list is as wide as the field', (tester) async {
    setView(tester, const Size(500, 800));
    await tester.pumpWidget(wrap(const Host()));

    await focusField(tester);
    expect(
      tester.getRect(list).width,
      moreOrLessEquals(tester.getRect(find.byType(KunInput)).width,
          epsilon: 0.5),
    );
  });

  testWidgets('disposing with the list open leaves no dismiss layer behind',
      (tester) async {
    setView(tester, const Size(500, 800));
    await tester.pumpWidget(wrap(const Host()));

    await focusField(tester);
    expect(KunDismissLayers.debugLayers, hasLength(1));

    await tester.pumpWidget(wrap(const SizedBox.shrink()));
    await tester.pumpAndSettle();
    expect(KunDismissLayers.debugLayers, isEmpty);
  });
}
