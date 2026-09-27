import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';
import 'package:kun_ui/src/foundation/dismiss_layers.dart';

Finder get panel =>
    find.byKey(const ValueKey<String>('KunChatMessageMenu.panel'));

Finder item(String key) =>
    find.byKey(ValueKey<String>('KunChatMessageMenu.item.$key'));

Finder quick(String key) =>
    find.byKey(ValueKey<String>('KunChatMessageMenu.quick.$key'));

Finder get more =>
    find.byKey(const ValueKey<String>('KunChatMessageMenu.more'));

const List<KunChatReactionOption> kReactions = <KunChatReactionOption>[
  KunChatReactionOption(key: 'heart', emoji: '❤️', label: 'Love'),
  KunChatReactionOption(key: 'fire', emoji: '🔥', label: 'Fire'),
  KunChatReactionOption(key: 'party', emoji: '🎉', label: 'Party'),
  KunChatReactionOption(key: 'clap', emoji: '👏', label: 'Clap'),
  KunChatReactionOption(key: 'think', emoji: '🤔', label: 'Think'),
  KunChatReactionOption(key: 'star', emoji: '⭐', label: 'Star'),
  KunChatReactionOption(key: 'eyes', emoji: '👀', label: 'Eyes'),
  KunChatReactionOption(key: 'wave', emoji: '👋', label: 'Wave'),
];

class _Host extends StatefulWidget {
  const _Host({
    this.startVisible = true,
    this.position,
    this.actions = const <KunChatMessageAction>[
      KunChatMessageAction.reply,
      KunChatMessageAction.copy,
    ],
    this.reactions = const <KunChatReactionOption>[],
    this.currentReaction,
    this.quickReactions = 7,
    this.onClose,
    this.onReact,
    this.onSelect,
    this.priorFocus,
  });

  final bool startVisible;
  final Offset? position;
  final List<KunChatMessageAction> actions;
  final List<KunChatReactionOption> reactions;
  final String? currentReaction;
  final int quickReactions;
  final VoidCallback? onClose;
  final ValueChanged<String?>? onReact;
  final ValueChanged<String>? onSelect;
  final FocusNode? priorFocus;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late bool _visible = widget.startVisible;

  @override
  void didUpdateWidget(covariant _Host oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startVisible != widget.startVisible) {
      _visible = widget.startVisible;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        if (widget.priorFocus != null)
          Focus(
            focusNode: widget.priorFocus,
            child: const SizedBox(width: 12, height: 12),
          ),
        KunChatMessageMenu(
          visible: _visible,
          position: widget.position,
          actions: widget.actions,
          reactions: widget.reactions,
          currentReaction: widget.currentReaction,
          quickReactions: widget.quickReactions,
          onClose: () {
            widget.onClose?.call();
            setState(() => _visible = false);
          },
          onReact: widget.onReact,
          onSelect: widget.onSelect,
        ),
      ],
    );
  }
}

Widget wrap(Widget child, {bool webEnter = false}) {
  Widget home = child;
  if (webEnter) {
    home = Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ButtonActivateIntent(),
      },
      child: home,
    );
  }
  return KunMessagesScope(
    messages: KunMessages.en,
    child: KunTheme(
      data: KunThemeData.light(),
      child: WidgetsApp(
        color: KunColors.black,
        debugShowCheckedModeBanner: false,
        builder: (BuildContext context, Widget? navigator) {
          final MediaQueryData data = MediaQuery.of(context);
          return MediaQuery(
            data: data.copyWith(disableAnimations: true),
            child: navigator!,
          );
        },
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
    ),
  );
}

void setView(
  WidgetTester tester,
  Size size, {
  FakeViewPadding padding = FakeViewPadding.zero,
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
  addTearDown(tester.view.reset);
}

Future<void> pumpHost(
  WidgetTester tester,
  Widget host, {
  bool webEnter = false,
}) async {
  await tester.pumpWidget(
    wrap(KeyedSubtree(key: UniqueKey(), child: host), webEnter: webEnter),
  );
  await tester.pump();
  await tester.pump();
}

bool focused(WidgetTester tester, Finder keyed) {
  return tester
      .widget<FocusableActionDetector>(
        find.descendant(
          of: keyed,
          matching: find.byType(FocusableActionDetector),
        ),
      )
      .focusNode!
      .hasPrimaryFocus;
}

void main() {
  test('built-in actions carry the web wire name and value equality', () {
    expect(
      KunChatMessageAction.reply,
      const KunChatBuiltInAction(KunChatMessageActionKey.reply),
    );
    expect(KunChatMessageAction.reply.wireName, 'reply');
    expect(
      KunChatMessageActionKey.values.map(
        (KunChatMessageActionKey k) => k.wireName,
      ),
      <String>[
        'reply',
        'quote',
        'copy',
        'edit',
        'pin',
        'unpin',
        'delete',
        'report',
        'retry',
      ],
    );
    const KunChatMessageMenuItem a = KunChatMessageMenuItem(
      key: 'translate',
      label: 'Translate',
    );
    const KunChatMessageMenuItem b = KunChatMessageMenuItem(
      key: 'translate',
      label: 'Translate',
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  testWidgets('visible shows the panel; hidden does not', (tester) async {
    setView(tester, const Size(800, 600));
    await pumpHost(tester, const _Host(startVisible: false));
    expect(panel, findsNothing);

    await pumpHost(tester, const _Host());
    expect(panel, findsOneWidget);
    expect(find.text('Reply'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
  });

  testWidgets('empty actions and reactions render nothing', (tester) async {
    setView(tester, const Size(800, 600));
    await pumpHost(
      tester,
      const _Host(
        actions: <KunChatMessageAction>[],
        reactions: <KunChatReactionOption>[],
      ),
    );
    expect(panel, findsNothing);
  });

  testWidgets('custom actions, currentReaction, quickReactions and reactions', (
    tester,
  ) async {
    setView(tester, const Size(800, 600));
    await pumpHost(
      tester,
      const _Host(
        actions: <KunChatMessageAction>[
          KunChatMessageAction.pin,
          KunChatMessageMenuItem(key: 'translate', label: 'Translate'),
          KunChatMessageAction.report,
        ],
        reactions: kReactions,
        currentReaction: 'heart',
        quickReactions: 2,
      ),
    );

    expect(find.text('Pin'), findsOneWidget);
    expect(find.text('Translate'), findsOneWidget);
    expect(find.text('Report'), findsOneWidget);
    expect(find.text('Reply'), findsNothing);
    expect(quick('heart'), findsOneWidget);
    expect(quick('fire'), findsOneWidget);
    expect(quick('party'), findsNothing);
    expect(more, findsOneWidget);
    expect(
      tester.getSemantics(quick('heart')),
      isSemantics(
        label: 'Love',
        isButton: true,
        hasToggledState: true,
        isToggled: true,
      ),
    );
    expect(
      tester.getSemantics(quick('fire')),
      isSemantics(
        label: 'Fire',
        isButton: true,
        hasToggledState: true,
        isToggled: false,
      ),
    );
  });

  testWidgets('null position matches Offset.zero after clamping', (
    tester,
  ) async {
    setView(tester, const Size(800, 600));
    await pumpHost(tester, const _Host());
    final Rect atOrigin = tester.getRect(panel);

    await pumpHost(tester, const _Host(position: Offset.zero));
    expect(tester.getRect(panel), atOrigin);
    expect(atOrigin.left, moreOrLessEquals(8, epsilon: 0.5));
    expect(atOrigin.top, moreOrLessEquals(8, epsilon: 0.5));
  });

  testWidgets('clamps at every screen edge', (tester) async {
    setView(tester, const Size(800, 600));
    const List<Offset> corners = <Offset>[
      Offset.zero,
      Offset(800, 0),
      Offset(0, 600),
      Offset(800, 600),
    ];
    for (final Offset at in corners) {
      await pumpHost(tester, _Host(position: at));
      final Rect box = tester.getRect(panel);
      expect(box.left, greaterThanOrEqualTo(8 - 0.5));
      expect(box.top, greaterThanOrEqualTo(8 - 0.5));
      expect(box.right, lessThanOrEqualTo(800 - 8 + 0.5));
      expect(box.bottom, lessThanOrEqualTo(600 - 8 + 0.5));
    }
  });

  testWidgets('clamps inside view padding', (tester) async {
    setView(
      tester,
      const Size(800, 600),
      padding: const FakeViewPadding(left: 12, top: 40, right: 10, bottom: 24),
    );
    await pumpHost(tester, const _Host(position: Offset.zero));
    final Rect box = tester.getRect(panel);
    expect(box.left, moreOrLessEquals(12 + 8, epsilon: 0.5));
    expect(box.top, moreOrLessEquals(40 + 8, epsilon: 0.5));

    await pumpHost(tester, const _Host(position: Offset(800, 600)));
    final Rect far = tester.getRect(panel);
    expect(far.right, moreOrLessEquals(800 - 10 - 8, epsilon: 0.5));
    expect(far.bottom, moreOrLessEquals(600 - 24 - 8, epsilon: 0.5));
  });

  testWidgets('select then close, in that order', (tester) async {
    setView(tester, const Size(800, 600));
    final List<String> log = <String>[];
    await pumpHost(
      tester,
      _Host(
        onSelect: (String key) => log.add('select:$key'),
        onClose: () => log.add('close'),
      ),
    );
    await tester.tap(find.text('Reply'));
    await tester.pump();
    await tester.pump();
    expect(log, <String>['select:reply', 'close']);
    expect(panel, findsNothing);
  });

  testWidgets('react then close, in that order, and toggle yields null', (
    tester,
  ) async {
    setView(tester, const Size(800, 600));
    final List<String> log = <String>[];
    await pumpHost(
      tester,
      _Host(
        reactions: kReactions,
        currentReaction: 'heart',
        onReact: (String? key) => log.add('react:$key'),
        onClose: () => log.add('close'),
      ),
    );
    await tester.tap(quick('heart'));
    await tester.pump();
    await tester.pump();
    expect(log, <String>['react:null', 'close']);
  });

  testWidgets('picking another reaction emits its key then close', (
    tester,
  ) async {
    setView(tester, const Size(800, 600));
    final List<String> log = <String>[];
    await pumpHost(
      tester,
      _Host(
        reactions: kReactions,
        onReact: (String? key) => log.add('react:$key'),
        onClose: () => log.add('close'),
      ),
    );
    await tester.tap(quick('fire'));
    await tester.pump();
    await tester.pump();
    expect(log, <String>['react:fire', 'close']);
  });

  testWidgets('a disabled item is inert', (tester) async {
    setView(tester, const Size(800, 600));
    String? selected;
    int closed = 0;
    await pumpHost(
      tester,
      _Host(
        actions: const <KunChatMessageAction>[
          KunChatMessageMenuItem(key: 'nope', label: 'Nope', disabled: true),
          KunChatMessageAction.copy,
        ],
        onSelect: (String key) => selected = key,
        onClose: () => closed++,
      ),
    );
    await tester.tap(find.text('Nope'));
    await tester.pump();
    expect(selected, isNull);
    expect(closed, 0);
    expect(panel, findsOneWidget);

    expect(
      tester.getSemantics(item('nope')),
      isSemantics(label: 'Nope', isEnabled: false),
    );
  });

  testWidgets('expand replaces the row and list with the real picker', (
    tester,
  ) async {
    setView(tester, const Size(800, 600));
    await pumpHost(
      tester,
      const _Host(reactions: kReactions, quickReactions: 7),
    );
    expect(find.byType(KunChatReactionPicker), findsNothing);
    expect(find.text('Reply'), findsOneWidget);
    expect(more, findsOneWidget);

    await tester.tap(more);
    await tester.pump();
    await tester.pump();

    expect(find.byType(KunChatReactionPicker), findsOneWidget);
    expect(find.text('Reply'), findsNothing);
    expect(more, findsNothing);
    expect(quick('heart'), findsNothing);
  });

  testWidgets('seven quick reactions all fit inside the panel', (tester) async {
    setView(tester, const Size(800, 600));
    await pumpHost(
      tester,
      const _Host(reactions: kReactions, quickReactions: 7),
    );
    const List<String> keys = <String>[
      'heart',
      'fire',
      'party',
      'clap',
      'think',
      'star',
      'eyes',
    ];
    final Rect panelBox = tester.getRect(panel);
    Offset? previous;
    for (final String key in keys) {
      final Rect box = tester.getRect(quick(key));
      expect(box.width, moreOrLessEquals(36, epsilon: 0.5));
      expect(box.height, moreOrLessEquals(36, epsilon: 0.5));
      expect(box.left, greaterThanOrEqualTo(panelBox.left - 0.5));
      expect(box.right, lessThanOrEqualTo(panelBox.right + 0.5));
      if (previous != null) {
        expect(box.left, greaterThan(previous.dx));
      }
      previous = Offset(box.left, box.top);
    }
  });

  testWidgets('the picker fires react then close', (tester) async {
    setView(tester, const Size(800, 600));
    final List<String> log = <String>[];
    await pumpHost(
      tester,
      _Host(
        reactions: kReactions,
        onReact: (String? key) => log.add('react:$key'),
        onClose: () => log.add('close'),
      ),
    );
    await tester.tap(more);
    await tester.pump();
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Wave'));
    await tester.pump();
    await tester.pump();
    expect(log, <String>['react:wave', 'close']);
  });

  testWidgets('focus lands on the first item on open', (tester) async {
    setView(tester, const Size(800, 600));
    await pumpHost(tester, const _Host(reactions: kReactions));
    expect(focused(tester, item('reply')), isTrue);
  });

  testWidgets('focus lands on the first reaction when there are no items', (
    tester,
  ) async {
    setView(tester, const Size(800, 600));
    await pumpHost(
      tester,
      const _Host(actions: <KunChatMessageAction>[], reactions: kReactions),
    );
    expect(focused(tester, quick('heart')), isTrue);
  });

  testWidgets('focus returns on close', (tester) async {
    setView(tester, const Size(800, 600));
    final FocusNode prior = FocusNode();
    addTearDown(prior.dispose);
    await tester.pumpWidget(
      wrap(_Host(priorFocus: prior, startVisible: false)),
    );
    await tester.pump();
    prior.requestFocus();
    await tester.pump();
    expect(prior.hasPrimaryFocus, isTrue);

    await tester.pumpWidget(wrap(_Host(priorFocus: prior)));
    await tester.pump();
    await tester.pump();
    expect(panel, findsOneWidget);
    expect(prior.hasPrimaryFocus, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump();
    expect(panel, findsNothing);
    expect(prior.hasPrimaryFocus, isTrue);
  });

  testWidgets('arrows, Home, End and Tab follow the web keyboard model', (
    tester,
  ) async {
    setView(tester, const Size(800, 600));
    await pumpHost(
      tester,
      const _Host(
        actions: <KunChatMessageAction>[
          KunChatMessageAction.reply,
          KunChatMessageAction.copy,
          KunChatMessageAction.pin,
        ],
        reactions: kReactions,
        quickReactions: 3,
      ),
    );
    expect(focused(tester, item('reply')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(focused(tester, item('copy')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(focused(tester, item('pin')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(focused(tester, item('copy')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(focused(tester, item('pin')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(focused(tester, item('reply')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focused(tester, quick('heart')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(focused(tester, quick('fire')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(focused(tester, quick('heart')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(focused(tester, more), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(focused(tester, quick('heart')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(focused(tester, item('reply')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(focused(tester, item('pin')), isTrue);
  });

  testWidgets('Tab closes when only one zone exists', (tester) async {
    setView(tester, const Size(800, 600));
    int closed = 0;
    await pumpHost(tester, _Host(onClose: () => closed++));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.pump();
    expect(closed, 1);
    expect(panel, findsNothing);
  });

  testWidgets('Enter activates the focused row with the web key map', (
    tester,
  ) async {
    setView(tester, const Size(800, 600));
    String? selected;
    await pumpHost(
      tester,
      _Host(onSelect: (String key) => selected = key),
      webEnter: true,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();
    expect(selected, 'reply');
    expect(panel, findsNothing);
  });

  testWidgets('hover focuses an item', (tester) async {
    setView(tester, const Size(800, 600));
    await pumpHost(
      tester,
      const _Host(
        actions: <KunChatMessageAction>[
          KunChatMessageAction.reply,
          KunChatMessageAction.copy,
        ],
      ),
    );
    final TestGesture gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(item('copy')));
    await tester.pump();
    expect(focused(tester, item('copy')), isTrue);
  });

  testWidgets('an outside tap, Escape, back, resize and outside wheel close', (
    tester,
  ) async {
    setView(tester, const Size(800, 600));

    int closed = 0;
    await pumpHost(
      tester,
      _Host(position: const Offset(400, 300), onClose: () => closed++),
    );
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    await tester.pump();
    expect(closed, 1);
    expect(panel, findsNothing);

    closed = 0;
    await pumpHost(tester, _Host(onClose: () => closed++));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump();
    expect(closed, 1);

    closed = 0;
    await pumpHost(tester, _Host(onClose: () => closed++));
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump();
    await tester.pump();
    expect(closed, 1);
    expect(KunDismissLayers.debugLayers, isEmpty);

    closed = 0;
    await pumpHost(tester, _Host(onClose: () => closed++));
    setView(tester, const Size(400, 300));
    await tester.pump();
    await tester.pump();
    expect(closed, 1);

    closed = 0;
    await pumpHost(
      tester,
      _Host(position: const Offset(400, 300), onClose: () => closed++),
    );
    final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(const Offset(10, 10)));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 40)));
    await tester.pump();
    expect(closed, 1);
  });

  testWidgets('a wheel inside the panel does not close it', (tester) async {
    setView(tester, const Size(800, 600));
    int closed = 0;
    await pumpHost(
      tester,
      _Host(
        position: const Offset(400, 300),
        reactions: kReactions,
        onClose: () => closed++,
      ),
    );
    final Offset center = tester.getCenter(panel);
    final TestPointer pointer = TestPointer(2, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(center));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 40)));
    await tester.pump();
    expect(closed, 0);
    expect(panel, findsOneWidget);
  });

  testWidgets('the panel is a menu and rows are menu items', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    setView(tester, const Size(800, 600));
    await pumpHost(
      tester,
      const _Host(reactions: kReactions, quickReactions: 2),
    );

    final SemanticsData menu = tester.getSemantics(panel).getSemanticsData();
    expect(menu.role, SemanticsRole.menu);
    expect(menu.label, 'Message actions');

    final SemanticsData reply =
        tester.getSemantics(item('reply')).getSemanticsData();
    expect(reply.role, SemanticsRole.menuItem);
    expect(reply.label, 'Reply');

    expect(
      tester.getSemantics(find.bySemanticsLabel('Reactions')),
      isSemantics(label: 'Reactions'),
    );
    semantics.dispose();
  });

  testWidgets('disposing an open menu leaves no dismiss layer behind', (
    tester,
  ) async {
    setView(tester, const Size(800, 600));
    await pumpHost(tester, const _Host());
    expect(KunDismissLayers.debugLayers, hasLength(1));

    await tester.pumpWidget(wrap(const SizedBox.shrink()));
    await tester.pump();
    expect(KunDismissLayers.debugLayers, isEmpty);
  });
}
