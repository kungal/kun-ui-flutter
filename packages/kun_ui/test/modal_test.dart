import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';
import 'package:kun_ui/src/foundation/dismiss_layers.dart';

Finder get panel => find.byKey(const ValueKey<String>('KunModal.panel'));
Finder get layer => find.byKey(const ValueKey<String>('KunModal.layer'));
Finder get backdrop => find.byKey(const ValueKey<String>('KunModal.backdrop'));
Finder get handle => find.byKey(const ValueKey<String>('KunModal.handle'));
Finder get panelTransform =>
    find.byKey(const ValueKey<String>('KunModal.panelTransform'));
Finder get insideScroll =>
    find.byKey(const ValueKey<String>('KunModal.insideScroll'));
Finder get outsideScroll =>
    find.byKey(const ValueKey<String>('KunModal.outsideScroll'));

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

void setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

double transformY(WidgetTester tester) {
  return tester.widget<Transform>(panelTransform).transform.getTranslation().y;
}

double transformScale(WidgetTester tester) {
  return tester
      .widget<Transform>(
        find.byKey(const ValueKey<String>('KunModal.panelScale')),
      )
      .transform
      .storage[0];
}

Finder scrollableOf(Finder parent) =>
    find.descendant(of: parent, matching: find.byType(Scrollable));

double layerOpacity(WidgetTester tester) {
  return tester.widget<FadeTransition>(layer).opacity.value;
}

class _Host extends StatefulWidget {
  const _Host({
    super.key,
    this.initial = false,
    this.title = 'Title',
    this.description = 'Description',
    this.child,
    this.semanticLabel,
    this.isDismissable,
    this.isCloseRequestDismissable = true,
    this.isSwipeDismissable = true,
    this.isShowCloseButton = true,
    this.withContainer = true,
    this.size = KunModalSize.md,
    this.scrollBehavior = KunModalScrollBehavior.inside,
    this.placement = KunModalPlacement.auto,
    this.role = KunModalRole.dialog,
    this.rounded,
    this.behind,
  });

  final bool initial;
  final String? title;
  final String? description;
  final Widget? child;
  final String? semanticLabel;
  final bool? isDismissable;
  final bool isCloseRequestDismissable;
  final bool isSwipeDismissable;
  final bool isShowCloseButton;
  final bool withContainer;
  final KunModalSize size;
  final KunModalScrollBehavior scrollBehavior;
  final KunModalPlacement placement;
  final KunModalRole role;
  final KunUIRounded? rounded;
  final Widget? behind;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late bool value = widget.initial;
  final List<String> events = <String>[];

  void open() => setState(() => value = true);

  void close() => setState(() => value = false);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (widget.behind != null) widget.behind!,
        KunButton(
          onPressed: open,
          child: const Text('Open'),
        ),
        KunModal(
          value: value,
          onChanged: (bool next) {
            events.add('onChanged:$next');
            setState(() => value = next);
          },
          onClose: () => events.add('onClose'),
          title: widget.title,
          description: widget.description,
          semanticLabel: widget.semanticLabel,
          isDismissable: widget.isDismissable,
          isCloseRequestDismissable: widget.isCloseRequestDismissable,
          isSwipeDismissable: widget.isSwipeDismissable,
          isShowCloseButton: widget.isShowCloseButton,
          withContainer: widget.withContainer,
          size: widget.size,
          scrollBehavior: widget.scrollBehavior,
          placement: widget.placement,
          role: widget.role,
          rounded: widget.rounded,
          child: widget.child ?? const SizedBox(width: 100, height: 20),
        ),
      ],
    );
  }
}

Future<_HostState> _pumpOpen(
  WidgetTester tester, {
  Key? key,
  Size size = const Size(1024, 768),
  String? title = 'Title',
  String? description = 'Description',
  Widget? child,
  String? semanticLabel,
  bool? isDismissable,
  bool isCloseRequestDismissable = true,
  bool isSwipeDismissable = true,
  bool isShowCloseButton = true,
  bool withContainer = true,
  KunModalSize modalSize = KunModalSize.md,
  KunModalScrollBehavior scrollBehavior = KunModalScrollBehavior.inside,
  KunModalPlacement placement = KunModalPlacement.auto,
  KunModalRole role = KunModalRole.dialog,
  KunUIRounded? rounded,
  Widget? behind,
  KunThemeData? theme,
  Widget Function(Widget child)? wrapHome,
  bool settle = true,
}) async {
  setView(tester, size);
  final GlobalKey<_HostState> hostKey =
      key is GlobalKey<_HostState> ? key : GlobalKey<_HostState>();
  await tester.pumpWidget(
    wrap(
      _Host(
        key: hostKey,
        initial: true,
        title: title,
        description: description,
        semanticLabel: semanticLabel,
        isDismissable: isDismissable,
        isCloseRequestDismissable: isCloseRequestDismissable,
        isSwipeDismissable: isSwipeDismissable,
        isShowCloseButton: isShowCloseButton,
        withContainer: withContainer,
        size: modalSize,
        scrollBehavior: scrollBehavior,
        placement: placement,
        role: role,
        rounded: rounded,
        behind: behind,
        child: child,
      ),
      theme: theme,
      wrapHome: wrapHome,
    ),
  );
  await tester.pump();
  if (settle) {
    await tester.pumpAndSettle();
  }
  return hostKey.currentState!;
}

void main() {
  testWidgets('value false draws nothing; turning true shows then parent close',
      (WidgetTester tester) async {
    setView(tester, const Size(1024, 768));
    final GlobalKey<_HostState> key = GlobalKey<_HostState>();
    await tester.pumpWidget(wrap(const _Host()));
    await tester.pump();
    expect(find.text('Title'), findsNothing);
    expect(panel, findsNothing);

    await tester.pumpWidget(wrap(_Host(key: key)));
    key.currentState!.open();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);

    final int before = key.currentState!.events.length;
    key.currentState!.close();
    await tester.pumpAndSettle();
    expect(find.text('Title'), findsNothing);
    expect(key.currentState!.events, isEmpty);
    expect(before, 0);
  });

  testWidgets('an open modal is one dismiss layer, and leaves none behind',
      (WidgetTester tester) async {
    expect(KunDismissLayers.debugLayers, isEmpty);
    final GlobalKey<_HostState> key = GlobalKey<_HostState>();
    await _pumpOpen(tester, key: key);
    expect(KunDismissLayers.debugLayers, hasLength(1));

    key.currentState!.close();
    await tester.pumpAndSettle();
    expect(KunDismissLayers.debugLayers, isEmpty);

    // Torn down with the modal open: a layer left behind would swallow the
    // next back gesture in the app, silently.
    await _pumpOpen(tester);
    expect(KunDismissLayers.debugLayers, hasLength(1));
    await tester.pumpWidget(wrap(const SizedBox.shrink()));
    await tester.pumpAndSettle();
    expect(KunDismissLayers.debugLayers, isEmpty);
  });

  testWidgets('initial value true opens after the first frame',
      (WidgetTester tester) async {
    setView(tester, const Size(1024, 768));
    await tester.pumpWidget(wrap(const _Host(initial: true)));
    expect(find.text('Title'), findsNothing);
    await tester.pump();
    expect(find.text('Title'), findsOneWidget);
  });

  testWidgets('parent rebuild while open updates child and title',
      (WidgetTester tester) async {
    setView(tester, const Size(1024, 768));
    final GlobalKey<_HostState> key = GlobalKey<_HostState>();
    await tester.pumpWidget(
      wrap(
        _Host(
          key: key,
          initial: true,
          title: 'One',
          child: const Text('body-one'),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('One'), findsOneWidget);
    expect(find.text('body-one'), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        _Host(
          key: key,
          initial: true,
          title: 'Two',
          child: const Text('body-two'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Two'), findsOneWidget);
    expect(find.text('body-two'), findsOneWidget);
    expect(find.text('One'), findsNothing);
  });

  testWidgets('captured scopes reach the open dialog',
      (WidgetTester tester) async {
    setView(tester, const Size(1024, 768));
    String? probe;
    await tester.pumpWidget(
      wrap(
        KunTheme(
          data: KunThemeData.dark(),
          child: KunMessagesScope(
            messages: KunMessages.en,
            child: KunUIConfigScope(
              config: const KunUIConfig(userLinkTemplate: '/probe/{id}'),
              child: _Host(
                initial: true,
                child: Builder(
                  builder: (BuildContext context) {
                    probe = KunUIConfigScope.of(context).userLinkTemplate;
                    return const Text('scoped');
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final DecoratedBox box = tester.widget<DecoratedBox>(panel);
    final BoxDecoration decoration = box.decoration as BoxDecoration;
    expect(decoration.color, KunColors.dark.content1);
    expect(
      tester.getSemantics(find.byIcon(KunIcons.x)).label,
      'Close',
    );
    expect(probe, '/probe/{id}');
  });

  testWidgets('close button dismisses in order and can be hidden',
      (WidgetTester tester) async {
    final _HostState host = await _pumpOpen(tester);
    await tester.tap(find.byIcon(KunIcons.x));
    await tester.pumpAndSettle();
    expect(host.events, <String>['onChanged:false', 'onClose']);
    expect(find.text('Title'), findsNothing);

    await _pumpOpen(tester, isShowCloseButton: false);
    expect(find.byIcon(KunIcons.x), findsNothing);
  });

  testWidgets('close button semantic label follows the messages scope',
      (WidgetTester tester) async {
    await _pumpOpen(tester);
    expect(
      tester.getSemantics(find.byIcon(KunIcons.x)).label,
      KunMessages.zhCN.modal.close,
    );
  });

  testWidgets('backdrop tap rules', (WidgetTester tester) async {
    _HostState host = await _pumpOpen(tester);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(host.events, <String>['onChanged:false', 'onClose']);

    host = await _pumpOpen(tester);
    await tester.tap(panel);
    await tester.pumpAndSettle();
    expect(host.events, isEmpty);
    expect(find.text('Title'), findsOneWidget);

    final Rect panelRect = tester.getRect(panel);
    final TestGesture gesture = await tester.startGesture(panelRect.center);
    await gesture.moveTo(const Offset(8, 8));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(host.events, isEmpty);

    host = await _pumpOpen(tester, role: KunModalRole.alertdialog);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(host.events, isEmpty);

    host = await _pumpOpen(
      tester,
      role: KunModalRole.alertdialog,
      isDismissable: true,
    );
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(host.events, <String>['onChanged:false', 'onClose']);

    host = await _pumpOpen(tester, isDismissable: false);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(host.events, isEmpty);

    host = await _pumpOpen(tester);
    await tester.tapAt(
      const Offset(8, 8),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(host.events, isEmpty);
  });

  testWidgets('backdrop colours', (WidgetTester tester) async {
    await _pumpOpen(tester);
    expect(
      tester.widget<ColoredBox>(backdrop).color,
      KunColors.light.neutral.shade800.withValues(alpha: 0.7),
    );

    await _pumpOpen(tester, theme: KunThemeData.dark());
    final Color dark = tester.widget<ColoredBox>(backdrop).color;
    expect(dark.a, closeTo(0.49, 1e-6));
    expect(dark, KunColors.dark.background.withValues(alpha: 0.7 * 0.7));
  });

  testWidgets(
      'Escape dismisses dialog and alertdialog unless isDismissable false',
      (WidgetTester tester) async {
    _HostState host = await _pumpOpen(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(host.events, <String>['onChanged:false', 'onClose']);

    host = await _pumpOpen(tester, role: KunModalRole.alertdialog);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(host.events, <String>['onChanged:false', 'onClose']);

    host = await _pumpOpen(tester, isDismissable: false);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(host.events, isEmpty);
    expect(find.text('Title'), findsOneWidget);
  });

  testWidgets('stacked modals: one Escape closes one layer',
      (WidgetTester tester) async {
    setView(tester, const Size(1024, 768));
    await tester.pumpWidget(wrap(const _Stacked()));
    await tester.tap(find.text('Open outer'));
    await tester.pumpAndSettle();
    expect(find.text('Outer'), findsOneWidget);
    await tester.tap(find.text('Open inner'));
    await tester.pumpAndSettle();
    expect(find.text('Inner'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Inner'), findsNothing);
    expect(find.text('Outer'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Outer'), findsNothing);
  });

  testWidgets('back dismisses with both callbacks',
      (WidgetTester tester) async {
    final _HostState host = await _pumpOpen(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(host.events, <String>['onChanged:false', 'onClose']);
  });

  testWidgets('back with isCloseRequestDismissable false forwards to the page',
      (WidgetTester tester) async {
    setView(tester, const Size(1024, 768));
    await tester.pumpWidget(wrap(const _BackHome()));
    await tester.tap(find.text('Push'));
    await tester.pumpAndSettle();
    expect(find.text('Dialog'), findsOneWidget);
    expect(find.text('home'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Dialog'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('parent close, disposal, external removal, reopen',
      (WidgetTester tester) async {
    setView(tester, const Size(1024, 768));
    final GlobalKey<_HostState> key = GlobalKey<_HostState>();
    await tester.pumpWidget(wrap(_Host(key: key, initial: true)));
    await tester.pump();
    await tester.pumpAndSettle();
    key.currentState!.close();
    await tester.pumpAndSettle();
    expect(key.currentState!.events, isEmpty);
    expect(find.text('Title'), findsNothing);

    key.currentState!.open();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Title'), findsOneWidget);

    await tester.pumpWidget(wrap(const SizedBox.shrink()));
    await tester.pump();
    expect(find.text('Title'), findsNothing);

    await tester.pumpWidget(wrap(_Host(key: key, initial: true)));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Title'), findsOneWidget);

    Navigator.of(tester.element(find.byType(_Host)))
        .popUntil((Route<dynamic> route) => route.isFirst);
    await tester.pumpAndSettle();
    expect(key.currentState!.events, <String>['onChanged:false']);
    expect(find.text('Title'), findsNothing);

    key.currentState!.open();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Title'), findsOneWidget);
  });

  testWidgets('layout at 1024 and 400', (WidgetTester tester) async {
    await _pumpOpen(
      tester,
      child: const SizedBox(width: 100, height: 20),
    );
    expect(tester.getSize(panel).width, 320);
    expect(
      tester.getRect(panel).center.dy,
      closeTo(384, 1),
    );
    final Padding panelPadding = tester.widget<Padding>(
      find.descendant(of: panel, matching: find.byType(Padding)).first,
    );
    expect(panelPadding.padding, const EdgeInsets.all(24));

    await _pumpOpen(
      tester,
      child: const SizedBox(width: 2000, height: 20),
    );
    expect(tester.getSize(panel).width, 448);

    await _pumpOpen(
      tester,
      modalSize: KunModalSize.sm,
      child: const SizedBox(width: 2000, height: 20),
    );
    expect(tester.getSize(panel).width, 384);

    await _pumpOpen(
      tester,
      modalSize: KunModalSize.lg,
      child: const SizedBox(width: 2000, height: 20),
    );
    expect(tester.getSize(panel).width, 512);

    await _pumpOpen(
      tester,
      modalSize: KunModalSize.xl,
      child: const SizedBox(width: 2000, height: 20),
    );
    expect(tester.getSize(panel).width, 672);

    await _pumpOpen(
      tester,
      modalSize: KunModalSize.full,
      child: const SizedBox(width: 100, height: 20),
    );
    expect(tester.getSize(panel).width, 1000);

    await _pumpOpen(tester, placement: KunModalPlacement.center);
    expect(tester.getRect(panel).center.dy, closeTo(384, 1));

    await _pumpOpen(tester, placement: KunModalPlacement.top);
    expect(tester.getRect(panel).top, 12);

    await _pumpOpen(
      tester,
      size: const Size(400, 800),
      child: const SizedBox(width: 100, height: 20),
    );
    expect(tester.getSize(panel).width, 392);
    expect(tester.getRect(panel).bottom, 796);

    await _pumpOpen(
      tester,
      size: const Size(400, 800),
      modalSize: KunModalSize.full,
    );
    expect(tester.getSize(panel).width, 392);

    tester.view.viewPadding = const FakeViewPadding(bottom: 34);
    tester.view.padding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetPadding);
    await _pumpOpen(tester, size: const Size(400, 800));
    expect(tester.getRect(panel).bottom, 766);
    tester.view.resetViewPadding();
    tester.view.resetPadding();

    await _pumpOpen(
      tester,
      size: const Size(400, 800),
      placement: KunModalPlacement.center,
      child: const SizedBox(width: 100, height: 20),
    );
    expect(tester.getSize(panel).width, 320);

    await _pumpOpen(
      tester,
      size: const Size(400, 800),
      placement: KunModalPlacement.center,
      child: const SizedBox(width: 2000, height: 20),
    );
    expect(tester.getSize(panel).width, 376);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await _pumpOpen(tester, size: const Size(400, 800));
    expect(tester.getRect(panel).bottom, 496);
  });

  testWidgets('inside and outside scrolling, Tab moves into view',
      (WidgetTester tester) async {
    await _pumpOpen(
      tester,
      child: const SizedBox(width: 100, height: 2000),
    );
    expect(tester.getSize(panel).height, 768 * 0.9);
    expect(insideScroll, findsOneWidget);
    expect(outsideScroll, findsNothing);
    final ScrollableState inside =
        tester.state<ScrollableState>(scrollableOf(insideScroll));
    expect(inside.position.maxScrollExtent, greaterThan(0));

    await _pumpOpen(
      tester,
      scrollBehavior: KunModalScrollBehavior.outside,
      child: const SizedBox(width: 100, height: 2000),
    );
    expect(tester.getSize(panel).height, greaterThan(768));
    expect(outsideScroll, findsOneWidget);
    expect(tester.getRect(panel).top, 44);
    final ScrollableState outside =
        tester.state<ScrollableState>(scrollableOf(outsideScroll));
    expect(outside.position.maxScrollExtent, greaterThan(0));

    await _pumpOpen(
      tester,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const <Widget>[
          KunButton(onPressed: _noop, child: Text('top-focus')),
          SizedBox(height: 2000),
          KunButton(onPressed: _noop, child: Text('bottom-focus')),
        ],
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final Rect panelRect = tester.getRect(panel);
    final Rect bottomRect = tester.getRect(find.text('bottom-focus'));
    expect(panelRect.intersect(bottomRect), bottomRect);

    await _pumpOpen(
      tester,
      scrollBehavior: KunModalScrollBehavior.outside,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const <Widget>[
          KunButton(onPressed: _noop, child: Text('top-out')),
          SizedBox(height: 2000),
          KunButton(onPressed: _noop, child: Text('bottom-out')),
        ],
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final Rect layerRect = tester.getRect(layer);
    final Rect bottomOut = tester.getRect(find.text('bottom-out'));
    expect(layerRect.overlaps(bottomOut), isTrue);
  });

  testWidgets('enter, exit and reduced-motion transitions',
      (WidgetTester tester) async {
    setView(tester, const Size(1024, 768));
    final GlobalKey<_HostState> key = GlobalKey<_HostState>();
    await tester.pumpWidget(wrap(_Host(key: key)));
    key.currentState!.open();
    await tester.pump();
    await tester.pump();
    await tester.pump(KunDurations.base ~/ 2);
    expect(layerOpacity(tester), greaterThan(0));
    expect(layerOpacity(tester), lessThan(1));
    expect(transformY(tester), greaterThan(0));
    expect(transformY(tester), lessThan(8));
    expect(transformScale(tester), greaterThan(0.96));
    expect(transformScale(tester), lessThan(1));
    await tester.pumpAndSettle();
    expect(layerOpacity(tester), 1);
    expect(transformY(tester), 0);
    expect(transformScale(tester), 1);

    key.currentState!.close();
    await tester.pump();
    await tester.pump(KunDurations.exit - const Duration(milliseconds: 10));
    expect(find.text('Title'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Title'), findsNothing);

    await _pumpOpen(tester, size: const Size(400, 800), settle: false);
    await tester.pump();
    await tester.pump(KunDurations.base ~/ 2);
    expect(transformY(tester), greaterThan(0));
    expect(transformY(tester), lessThan(80));
    expect(transformScale(tester), 1);
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      wrap(
        const _Host(initial: true),
        wrapHome: (Widget child) {
          return MediaQuery(
            data: const MediaQueryData(
              size: Size(1024, 768),
              disableAnimations: true,
            ),
            child: child,
          );
        },
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(layerOpacity(tester), 1);
    expect(transformY(tester), 0);
    expect(transformScale(tester), 1);

    final GlobalKey<_HostState> reducedKey = GlobalKey<_HostState>();
    await tester.pumpWidget(
      wrap(
        _Host(key: reducedKey, initial: true),
        wrapHome: (Widget child) {
          return MediaQuery(
            data: const MediaQueryData(
              size: Size(1024, 768),
              disableAnimations: true,
            ),
            child: child,
          );
        },
      ),
    );
    await tester.pump();
    await tester.pump();
    reducedKey.currentState!.close();
    await tester.pump();
    await tester.pump();
    expect(find.text('Title'), findsNothing);
  });

  testWidgets('focus trap, modality and return', (WidgetTester tester) async {
    final FocusHighlightStrategy previous =
        FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() {
      FocusManager.instance.highlightStrategy = previous;
    });

    setView(tester, const Size(1024, 768));
    final GlobalKey<_HostState> key = GlobalKey<_HostState>();
    final FocusNode behind = FocusNode();
    addTearDown(behind.dispose);
    await tester.pumpWidget(
      wrap(
        _Host(
          key: key,
          behind: Focus(
            focusNode: behind,
            child: const KunButton(onPressed: _noop, child: Text('behind')),
          ),
          child: const KunButton(onPressed: _noop, child: Text('first')),
        ),
      ),
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    key.currentState!.open();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pump();
    expect(find.text('first'), findsOneWidget);
    expect(
      Focus.maybeOf(tester.element(find.text('first')))?.hasFocus ?? false,
      isTrue,
      reason:
          'close=${Focus.maybeOf(tester.element(find.byIcon(KunIcons.x)))?.hasFocus} '
          'primary=${FocusManager.instance.primaryFocus?.debugLabel} '
          '${FocusManager.instance.primaryFocus?.context?.widget.runtimeType}',
    );

    await tester.pumpWidget(wrap(const SizedBox.shrink()));
    await tester.pump();

    await tester.pumpWidget(
      wrap(
        _Host(
          key: key,
          behind: Focus(
            focusNode: behind,
            child: const KunButton(onPressed: _noop, child: Text('behind')),
          ),
          child: const KunButton(onPressed: _noop, child: Text('first')),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      Focus.of(tester.element(find.text('first'))).hasFocus,
      isFalse,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      Focus.of(tester.element(find.text('first'))).hasFocus,
      isTrue,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(behind.hasFocus, isFalse);
    expect(
      Focus.of(tester.element(find.text('first'))).hasFocus,
      isTrue,
    );

    await tester.tap(find.byIcon(KunIcons.x));
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pump();
    expect(find.text('Title'), findsNothing);
    expect(behind.hasFocus, isFalse);
  });

  testWidgets('semantics, scopesRoute, no-name warning',
      (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final DebugPrintCallback previousPrint = debugPrint;
    try {
      await _pumpOpen(
        tester,
        behind: const KunButton(onPressed: _noop, child: Text('behind')),
      );

      SemanticsNode? dialog;
      void walk(SemanticsNode node) {
        if (node.getSemanticsData().role == SemanticsRole.dialog) {
          dialog = node;
        }
        node.visitChildren((SemanticsNode child) {
          walk(child);
          return true;
        });
      }

      walk(tester
          .binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
      expect(dialog, isNotNull);
      final SemanticsData data = dialog!.getSemanticsData();
      expect(data.flagsCollection.scopesRoute, isTrue);
      expect(data.flagsCollection.namesRoute, isTrue);
      expect(data.label, 'Title');
      expect(data.hint, 'Description');
      bool foundBehind = false;
      void walkBehind(SemanticsNode node) {
        if (node.getSemanticsData().label == 'behind') {
          foundBehind = true;
        }
        node.visitChildren((SemanticsNode child) {
          walkBehind(child);
          return true;
        });
      }

      walkBehind(tester
          .binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
      expect(foundBehind, isFalse);

      await _pumpOpen(
        tester,
        title: 'Alert',
        role: KunModalRole.alertdialog,
      );
      SemanticsNode? alert;
      void walkAlert(SemanticsNode node) {
        if (node.getSemanticsData().role == SemanticsRole.alertDialog) {
          alert = node;
        }
        node.visitChildren((SemanticsNode child) {
          walkAlert(child);
          return true;
        });
      }

      walkAlert(tester
          .binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
      expect(alert, isNotNull);

      await _pumpOpen(tester, title: null, semanticLabel: 'Named');
      SemanticsNode? labelled;
      void walkLabel(SemanticsNode node) {
        if (node.getSemanticsData().role == SemanticsRole.dialog) {
          labelled = node;
        }
        node.visitChildren((SemanticsNode child) {
          walkLabel(child);
          return true;
        });
      }

      walkLabel(tester
          .binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
      expect(labelled!.getSemanticsData().label, 'Named');

      final List<String> printed = <String>[];
      debugPrint = (String? message, {int? wrapWidth}) {
        printed.add(message ?? '');
      };
      await _pumpOpen(tester, title: null, description: null);
      expect(
        printed.any((String line) =>
            line.contains('title') && line.contains('semanticLabel')),
        isTrue,
      );
      printed.clear();
      await _pumpOpen(tester, title: 'Has title');
      expect(
        printed.any((String line) => line.contains('semanticLabel')),
        isFalse,
      );
    } finally {
      debugPrint = previousPrint;
      semantics.dispose();
    }
  });

  testWidgets('swipe to dismiss on a touch-first sheet',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });
    try {
      _HostState host = await _pumpOpen(
        tester,
        size: const Size(400, 800),
        child: const SizedBox(width: 100, height: 200),
      );
      expect(handle, findsOneWidget);

      final TestGesture held =
          await tester.startGesture(tester.getCenter(panel));
      await held.moveBy(const Offset(0, 40));
      await tester.pump();
      expect(transformY(tester), closeTo(40, 1));
      await held.up();
      await tester.pump();
      await tester.pump(KunDurations.base);
      expect(transformY(tester), closeTo(0, 1));
      expect(find.text('Title'), findsOneWidget);

      final double height = tester.getSize(panel).height;
      await tester.drag(panel, Offset(0, height * 0.3));
      await tester.pumpAndSettle();
      expect(host.events, <String>['onChanged:false', 'onClose']);

      host = await _pumpOpen(
        tester,
        size: const Size(400, 800),
        child: const SizedBox(width: 100, height: 200),
      );
      await tester.fling(panel, const Offset(0, 80), 800);
      await tester.pumpAndSettle();
      expect(host.events, <String>['onChanged:false', 'onClose']);

      host = await _pumpOpen(
        tester,
        size: const Size(400, 800),
        child: const SizedBox(width: 100, height: 200),
      );
      final TestGesture rubber =
          await tester.startGesture(tester.getCenter(panel));
      await rubber.moveBy(const Offset(0, 20));
      await tester.pump();
      await rubber.moveBy(const Offset(0, -200));
      await tester.pump();
      expect(transformY(tester), greaterThan(-32.01));
      expect(transformY(tester), lessThan(20));
      await rubber.up();
      await tester.pumpAndSettle();

      host = await _pumpOpen(
        tester,
        size: const Size(400, 800),
        child: const SizedBox(width: 100, height: 2000),
      );
      final ScrollableState scroll =
          tester.state<ScrollableState>(scrollableOf(insideScroll));
      scroll.position.jumpTo(80);
      await tester.pump();
      final double tyBefore = transformY(tester);
      await tester.drag(panel, const Offset(0, 40));
      await tester.pump();
      expect(transformY(tester), closeTo(tyBefore, 1));
      expect(scroll.position.pixels, isNot(80));
      tester
          .state<ScrollableState>(scrollableOf(insideScroll))
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      expect(
        tester
            .state<ScrollableState>(scrollableOf(insideScroll))
            .position
            .pixels,
        0,
      );
      expect(
        tester
            .state<ScrollableState>(scrollableOf(insideScroll))
            .position
            .isScrollingNotifier
            .value,
        isFalse,
      );
      final TestGesture fromTop =
          await tester.startGesture(tester.getCenter(panel));
      await fromTop.moveBy(const Offset(0, 40));
      await tester.pump();
      expect(transformY(tester), closeTo(40, 1));
      await fromTop.up();
      await tester.pumpAndSettle();

      host = await _pumpOpen(
        tester,
        size: const Size(400, 800),
        child: const SizedBox(
          width: 280,
          child: KunInput(value: 'hello'),
        ),
      );
      final double inputTy = transformY(tester);
      await tester.drag(find.byType(KunInput), const Offset(0, 40));
      await tester.pump();
      expect(transformY(tester), closeTo(inputTy, 1));

      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      await tester.pump();
      await _pumpOpen(tester, size: const Size(400, 800), settle: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      final double enterTy = transformY(tester);
      final TestGesture duringEnter =
          await tester.startGesture(tester.getCenter(panel));
      await duringEnter.moveBy(const Offset(0, 40));
      await tester.pump();
      expect((transformY(tester) - enterTy).abs(), lessThan(8));
      await duringEnter.up();
      await tester.pumpAndSettle();

      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      host = await _pumpOpen(
        tester,
        size: const Size(400, 800),
        child: const SizedBox(width: 100, height: 200),
      );
      expect(handle, findsNothing);
      await tester.drag(panel, const Offset(0, 80));
      await tester.pumpAndSettle();
      expect(host.events, isEmpty);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      host = await _pumpOpen(
        tester,
        size: const Size(400, 800),
        placement: KunModalPlacement.center,
      );
      expect(handle, findsNothing);

      host = await _pumpOpen(
        tester,
        size: const Size(400, 800),
        role: KunModalRole.alertdialog,
      );
      expect(handle, findsNothing);

      host = await _pumpOpen(
        tester,
        size: const Size(400, 800),
        isSwipeDismissable: false,
      );
      expect(handle, findsNothing);

      var presses = 0;
      host = await _pumpOpen(
        tester,
        size: const Size(400, 800),
        child: KunButton(
          onPressed: () => presses += 1,
          child: const Text('Hold'),
        ),
      );
      await tester.drag(find.text('Hold'), const Offset(0, 40));
      await tester.pumpAndSettle();
      expect(presses, 0);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('withContainer false shows the child without a panel',
      (WidgetTester tester) async {
    await _pumpOpen(
      tester,
      withContainer: false,
      child: const Text('bare-child'),
    );
    expect(find.text('bare-child'), findsOneWidget);
    expect(panel, findsNothing);
    expect(find.byIcon(KunIcons.x), findsNothing);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'KunModal.panel');

    final SemanticsHandle semantics = tester.ensureSemantics();
    try {
      bool foundDialog = false;
      void walk(SemanticsNode node) {
        if (node.getSemanticsData().role == SemanticsRole.dialog) {
          foundDialog = true;
        }
        node.visitChildren((SemanticsNode child) {
          walk(child);
          return true;
        });
      }

      walk(tester
          .binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
      expect(foundDialog, isFalse);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('live placement switches sheet and centre on resize',
      (WidgetTester tester) async {
    await _pumpOpen(tester);
    expect(tester.getRect(panel).center.dy, closeTo(384, 20));

    tester.view.physicalSize = const Size(400, 800);
    await tester.pump();
    expect(tester.getSize(panel).width, 392);
    expect(tester.getRect(panel).bottom, closeTo(796, 1));

    tester.view.physicalSize = const Size(1024, 768);
    await tester.pump();
    expect(tester.getRect(panel).center.dy, closeTo(384, 20));
  });

  testWidgets('focus returns to the trigger after the dialog closes',
      (WidgetTester tester) async {
    final FocusHighlightStrategy previous =
        FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() {
      FocusManager.instance.highlightStrategy = previous;
    });
    setView(tester, const Size(1024, 768));
    await tester.pumpWidget(
      wrap(
        const _Host(
          child: KunButton(onPressed: _noop, child: Text('first')),
        ),
      ),
    );
    final FocusNode trigger = Focus.of(tester.element(find.text('Open')));
    trigger.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Title'), findsOneWidget);
    expect(trigger.hasFocus, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Title'), findsNothing);
    expect(trigger.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(KunIcons.x));
    await tester.pumpAndSettle();
    expect(find.text('Title'), findsNothing);
    expect(trigger.hasFocus, isTrue);
  });

  group('a field that autofocuses', () {
    Widget body(FocusNode field) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const KunButton(onPressed: _noop, child: Text('first')),
          KunTextarea(autofocus: true, focusNode: field),
        ],
      );
    }

    testWidgets('keeps the focus when a pointer opens the dialog',
        (WidgetTester tester) async {
      setView(tester, const Size(1024, 768));
      final FocusNode field = FocusNode();
      addTearDown(field.dispose);
      await tester.pumpWidget(wrap(_Host(child: body(field))));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(field.hasPrimaryFocus, isTrue);
    });

    testWidgets('keeps the focus when the keyboard opens the dialog',
        (WidgetTester tester) async {
      final FocusHighlightStrategy previous =
          FocusManager.instance.highlightStrategy;
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() {
        FocusManager.instance.highlightStrategy = previous;
      });
      setView(tester, const Size(1024, 768));
      final FocusNode field = FocusNode();
      addTearDown(field.dispose);
      await tester.pumpWidget(wrap(_Host(child: body(field))));
      Focus.of(tester.element(find.text('Open'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(field.hasPrimaryFocus, isTrue);
      expect(Focus.of(tester.element(find.text('first'))).hasFocus, isFalse);
    });

    testWidgets('keeps the focus in a dialog mounted open',
        (WidgetTester tester) async {
      final FocusNode field = FocusNode();
      addTearDown(field.dispose);
      await _pumpOpen(tester, child: body(field));
      expect(field.hasPrimaryFocus, isTrue);
    });
  });

  testWidgets('content without intrinsic sizes lays out in the panel',
      (WidgetTester tester) async {
    await _pumpOpen(
      tester,
      child: KunTab<KunTabItem>(
        items: const <KunTabItem>[
          KunTabItem(value: 'a', textValue: 'A'),
          KunTabItem(value: 'b', textValue: 'B'),
        ],
        value: 'a',
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('A'), findsOneWidget);

    await _pumpOpen(
      tester,
      child: SizedBox(
        height: 120,
        child: ListView(children: const <Widget>[Text('row')]),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(panel).width, 448);
  });

  group('swipe, continued', () {
    testWidgets('a claimed swipe holds the content under it',
        (WidgetTester tester) async {
      await onIOS(() async {
        await _pumpOpen(
          tester,
          size: const Size(400, 800),
          child: SizedBox(
            width: 100,
            height: 300,
            child: ListView(
              children: <Widget>[
                for (int i = 0; i < 30; i++)
                  SizedBox(height: 40, child: Text('row $i')),
              ],
            ),
          ),
        );
        final ScrollPosition list = tester
            .state<ScrollableState>(scrollableOf(find.byType(ListView)))
            .position;
        final TestGesture drag =
            await tester.startGesture(tester.getCenter(find.byType(ListView)));
        await drag.moveBy(const Offset(0, 30));
        await tester.pump();
        await drag.moveBy(const Offset(0, 30));
        await tester.pump();
        expect(transformY(tester), closeTo(60, 1));
        expect(list.pixels, 0);

        await drag.moveBy(const Offset(0, -120));
        await tester.pump();
        expect(transformY(tester), lessThan(0));
        expect(list.pixels, 0);

        await drag.up();
        await tester.pumpAndSettle();
        expect(list.pixels, 0);
        expect(transformY(tester), closeTo(0, 0.5));
        expect(find.text('Title'), findsOneWidget);
      });
    });

    testWidgets('no swipe for center, alertdialog or isSwipeDismissable false',
        (WidgetTester tester) async {
      await onIOS(() async {
        for (final (KunModalPlacement placement, KunModalRole role, bool swipe)
            in <(KunModalPlacement, KunModalRole, bool)>[
          (KunModalPlacement.center, KunModalRole.dialog, true),
          (KunModalPlacement.auto, KunModalRole.alertdialog, true),
          (KunModalPlacement.auto, KunModalRole.dialog, false),
        ]) {
          final _HostState host = await _pumpOpen(
            tester,
            size: const Size(400, 800),
            placement: placement,
            role: role,
            isSwipeDismissable: swipe,
          );
          final double ty = transformY(tester);
          final TestGesture drag =
              await tester.startGesture(tester.getCenter(panel));
          await drag.moveBy(const Offset(0, 150));
          await tester.pump();
          expect(transformY(tester), ty, reason: '$placement $role $swipe');
          await drag.up();
          await tester.pumpAndSettle();
          expect(host.events, isEmpty, reason: '$placement $role $swipe');
          expect(find.text('Title'), findsOneWidget);
        }
      });
    });

    testWidgets('a thrown sheet carries on down while the layer fades',
        (WidgetTester tester) async {
      await onIOS(() async {
        final _HostState host = await _pumpOpen(
          tester,
          size: const Size(400, 800),
          child: const SizedBox(width: 100, height: 200),
        );
        final double height = tester.getSize(panel).height;
        final TestGesture drag =
            await tester.startGesture(tester.getCenter(panel));
        await drag.moveBy(Offset(0, height * 0.3));
        await tester.pump();
        final double released = transformY(tester);
        expect(released, closeTo(height * 0.3, 1));

        await drag.up();
        await tester.pump();
        await tester.pump(KunDurations.exit ~/ 2);
        expect(transformY(tester), greaterThan(released));
        expect(transformY(tester), lessThan(height));
        expect(layerOpacity(tester), inExclusiveRange(0, 1));
        expect(host.events, <String>['onChanged:false', 'onClose']);

        await tester.pump(KunDurations.exit ~/ 2);
        expect(transformY(tester), closeTo(height, 0.5));
        expect(layerOpacity(tester), 0);
        await tester.pumpAndSettle();
        expect(panel, findsNothing);
      });
    });

    testWidgets('no swipe from the backdrop or while content settles',
        (WidgetTester tester) async {
      await onIOS(() async {
        await _pumpOpen(
          tester,
          size: const Size(400, 800),
          child: SizedBox(
            width: 100,
            height: 300,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: <Widget>[
                for (int i = 0; i < 30; i++)
                  SizedBox(height: 40, child: Text('row $i')),
              ],
            ),
          ),
        );
        final double top = tester.getRect(panel).top;
        final TestGesture fromBackdrop =
            await tester.startGesture(Offset(200, top - 100));
        await fromBackdrop.moveBy(const Offset(0, 60));
        await tester.pump();
        expect(transformY(tester), 0);
        await fromBackdrop.up();
        await tester.pumpAndSettle();

        final ScrollPosition list = tester
            .state<ScrollableState>(scrollableOf(find.byType(ListView)))
            .position;
        list.jumpTo(-40);
        await tester.pump();
        expect(list.isScrollingNotifier.value, isTrue);
        final TestGesture settling =
            await tester.startGesture(tester.getCenter(find.byType(ListView)));
        await settling.moveBy(const Offset(0, 60));
        await tester.pump();
        expect(transformY(tester), 0);
        await settling.up();
        await tester.pumpAndSettle();
        expect(find.text('Title'), findsOneWidget);
      });
    });

    testWidgets('a second finger does not strand a swipe',
        (WidgetTester tester) async {
      await onIOS(() async {
        await _pumpOpen(
          tester,
          size: const Size(400, 800),
          child: const SizedBox(width: 100, height: 200),
        );
        final Offset centre = tester.getCenter(panel);
        final TestGesture first = await tester.startGesture(centre, pointer: 1);
        await first.moveBy(const Offset(0, 40));
        await tester.pump();
        expect(transformY(tester), closeTo(40, 1));

        final TestGesture second = await tester.startGesture(
          centre + const Offset(40, 0),
          pointer: 2,
        );
        await second.moveBy(const Offset(0, 10));
        await tester.pump();
        expect(transformY(tester), closeTo(40, 1));

        await first.up();
        await tester.pumpAndSettle();
        expect(transformY(tester), closeTo(0, 0.5));
        await second.up();
        await tester.pumpAndSettle();
        expect(find.text('Title'), findsOneWidget);
      });
    });
  });
}

void _noop() {}

Future<void> onIOS(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

class _Stacked extends StatefulWidget {
  const _Stacked();

  @override
  State<_Stacked> createState() => _StackedState();
}

class _StackedState extends State<_Stacked> {
  bool outer = false;
  bool inner = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        KunButton(
          onPressed: () => setState(() => outer = true),
          child: const Text('Open outer'),
        ),
        KunModal(
          value: outer,
          onChanged: (bool value) => setState(() => outer = value),
          title: 'Outer',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              KunButton(
                onPressed: () => setState(() => inner = true),
                child: const Text('Open inner'),
              ),
              KunModal(
                value: inner,
                onChanged: (bool value) => setState(() => inner = value),
                title: 'Inner',
                child: const Text('Inner body'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BackHome extends StatelessWidget {
  const _BackHome();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const Text('home'),
        KunButton(
          onPressed: () {
            Navigator.of(context).push<void>(
              PageRouteBuilder<void>(
                pageBuilder: (
                  BuildContext context,
                  Animation<double> animation,
                  Animation<double> secondaryAnimation,
                ) {
                  return const _Host(
                    initial: true,
                    title: 'Dialog',
                    isCloseRequestDismissable: false,
                  );
                },
              ),
            );
          },
          child: const Text('Push'),
        ),
      ],
    );
  }
}
