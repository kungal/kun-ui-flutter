import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Finder get panel => find.byKey(const ValueKey<String>('KunModal.panel'));
Finder get layer => find.byKey(const ValueKey<String>('KunModal.layer'));
Finder get backdrop => find.byKey(const ValueKey<String>('KunModal.backdrop'));

Widget wrap(
  Widget child, {
  KunThemeData? theme,
  Widget Function(Widget child)? wrapHome,
  bool webKeys = false,
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
      shortcuts: webKeys
          ? <ShortcutActivator, Intent>{
              ...WidgetsApp.defaultShortcuts,
              const SingleActivator(LogicalKeyboardKey.enter):
                  const ButtonActivateIntent(),
            }
          : null,
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

double layerOpacity(WidgetTester tester) {
  return tester.widget<FadeTransition>(layer).opacity.value;
}

class _Host extends StatefulWidget {
  const _Host({this.onReady});

  final void Function(BuildContext context)? onReady;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  @override
  Widget build(BuildContext context) {
    widget.onReady?.call(context);
    return const SizedBox.expand();
  }
}

Future<BuildContext> pumpHost(
  WidgetTester tester, {
  Size size = const Size(1024, 768),
  KunThemeData? theme,
  Widget Function(Widget child)? wrapHome,
  bool webKeys = false,
}) async {
  setView(tester, size);
  BuildContext? saved;
  await tester.pumpWidget(
    wrap(
      _Host(onReady: (BuildContext context) => saved = context),
      theme: theme,
      wrapHome: wrapHome,
      webKeys: webKeys,
    ),
  );
  await tester.pump();
  return saved!;
}

void main() {
  testWidgets('confirm resolves true, cancel false, dialog gone',
      (WidgetTester tester) async {
    BuildContext context = await pumpHost(tester);
    final Future<bool> confirmed = showKunAlert(
      context,
      title: 'Delete?',
      message: 'Gone for good.',
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Delete?'), findsOneWidget);
    await tester.tap(find.text(KunMessages.zhCN.alert.confirm));
    await tester.pumpAndSettle();
    expect(await confirmed, isTrue);
    expect(panel, findsNothing);

    context = await pumpHost(tester);
    final Future<bool> cancelled = showKunAlert(
      context,
      title: 'Delete?',
      message: 'Gone for good.',
    );
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.tap(find.text(KunMessages.zhCN.alert.cancel));
    await tester.pumpAndSettle();
    expect(await cancelled, isFalse);
    expect(panel, findsNothing);
  });

  testWidgets('Escape back close button resolve false, backdrop ignored',
      (WidgetTester tester) async {
    BuildContext context = await pumpHost(tester);
    final Future<bool> escaped = showKunAlert(
      context,
      title: 'Delete?',
      message: 'Gone for good.',
    );
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(await escaped, isFalse);
    expect(panel, findsNothing);

    context = await pumpHost(tester);
    final Future<bool> backed = showKunAlert(
      context,
      title: 'Delete?',
      message: 'Gone for good.',
    );
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(await backed, isFalse);
    expect(panel, findsNothing);

    context = await pumpHost(tester);
    final Future<bool> closed = showKunAlert(
      context,
      title: 'Delete?',
      message: 'Gone for good.',
    );
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(KunIcons.x));
    await tester.pumpAndSettle();
    expect(await closed, isFalse);
    expect(panel, findsNothing);

    context = await pumpHost(tester);
    final Future<bool> backdropTap = showKunAlert(
      context,
      title: 'Delete?',
      message: 'Gone for good.',
    );
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);
    await tester.tap(find.text(KunMessages.zhCN.alert.cancel));
    await tester.pumpAndSettle();
    expect(await backdropTap, isFalse);
  });

  testWidgets('replacement completes the first false without exit animation',
      (WidgetTester tester) async {
    final BuildContext context = await pumpHost(tester);
    final Future<bool> first = showKunAlert(
      context,
      title: 'First',
      message: 'One',
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(layerOpacity(tester), 1);

    final Future<bool> second = showKunAlert(
      context,
      title: 'Second',
      message: 'Two',
    );
    await tester.pump();
    expect(await first, isFalse);
    expect(panel, findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
    expect(find.text('First'), findsNothing);
    expect(layerOpacity(tester), 1);

    await tester.tap(find.text(KunMessages.zhCN.alert.confirm));
    await tester.pumpAndSettle();
    expect(await second, isTrue);
  });

  testWidgets('buttons labels colours and showCancel',
      (WidgetTester tester) async {
    BuildContext context = await pumpHost(tester);
    showKunAlert(context, title: 'Delete?', message: 'Gone for good.');
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text(KunMessages.zhCN.alert.confirm), findsOneWidget);
    expect(find.text(KunMessages.zhCN.alert.cancel), findsOneWidget);
    await tester.tap(find.byIcon(KunIcons.x));
    await tester.pumpAndSettle();

    context = await pumpHost(
      tester,
      wrapHome: (Widget child) {
        return KunMessagesScope(messages: KunMessages.en, child: child);
      },
    );
    showKunAlert(context, title: 'Delete?', message: 'Gone for good.');
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text(KunMessages.en.alert.confirm), findsOneWidget);
    expect(find.text(KunMessages.en.alert.cancel), findsOneWidget);
    await tester.tap(find.byIcon(KunIcons.x));
    await tester.pumpAndSettle();

    context = await pumpHost(tester);
    showKunAlert(
      context,
      title: 'Delete?',
      message: 'Gone for good.',
      confirmText: 'Drop',
      cancelText: 'Keep',
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Drop'), findsOneWidget);
    expect(find.text('Keep'), findsOneWidget);
    await tester.tap(find.byIcon(KunIcons.x));
    await tester.pumpAndSettle();

    context = await pumpHost(tester);
    showKunAlert(
      context,
      title: 'Delete?',
      message: 'Gone for good.',
      confirmText: '',
      cancelText: '',
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text(KunMessages.zhCN.alert.confirm), findsOneWidget);
    expect(find.text(KunMessages.zhCN.alert.cancel), findsOneWidget);
    await tester.tap(find.byIcon(KunIcons.x));
    await tester.pumpAndSettle();

    context = await pumpHost(tester);
    showKunAlert(
      context,
      title: 'Delete?',
      message: 'Gone for good.',
      showCancel: false,
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text(KunMessages.zhCN.alert.cancel), findsNothing);
    expect(find.text(KunMessages.zhCN.alert.confirm), findsOneWidget);
    await tester.tap(find.byIcon(KunIcons.x));
    await tester.pumpAndSettle();

    Future<void> expectConfirmColor(
      KunAlertType type,
      KunUIColor color, {
      KunUIColor? confirmColor,
    }) async {
      final BuildContext ctx = await pumpHost(tester);
      showKunAlert(
        ctx,
        title: 'T',
        message: 'M',
        type: type,
        confirmColor: confirmColor,
      );
      await tester.pump();
      await tester.pumpAndSettle();
      final List<KunButton> buttons = tester
          .widgetList<KunButton>(find.byType(KunButton))
          .where((KunButton b) => !b.isIconOnly)
          .toList();
      expect(buttons.last.color, color);
      expect(buttons.last.variant, KunUIVariant.solid);
      if (buttons.length > 1) {
        expect(buttons.first.variant, KunUIVariant.light);
        expect(buttons.first.color, KunUIColor.neutral);
      }
      await tester.tap(find.byIcon(KunIcons.x));
      await tester.pumpAndSettle();
    }

    await expectConfirmColor(KunAlertType.info, KunUIColor.primary);
    await expectConfirmColor(KunAlertType.warning, KunUIColor.warning);
    await expectConfirmColor(KunAlertType.danger, KunUIColor.danger);
    await expectConfirmColor(
      KunAlertType.danger,
      KunUIColor.success,
      confirmColor: KunUIColor.success,
    );
  });

  testWidgets('layout at 1024x768', (WidgetTester tester) async {
    final BuildContext context = await pumpHost(tester);
    showKunAlert(
      context,
      title: 'Delete?',
      message: 'Gone for good.',
    );
    await tester.pump();
    await tester.pumpAndSettle();
    final Rect panelRect = tester.getRect(panel);
    expect(panelRect.width, 320);
    final Finder confirmButton = find.widgetWithText(
      KunButton,
      KunMessages.zhCN.alert.confirm,
    );
    final Rect confirm = tester.getRect(confirmButton);
    expect(panelRect.right - confirm.right, 24);
    expect(
      tester.getRect(find.text('Gone for good.')).top -
          tester.getRect(find.text('Delete?')).bottom,
      8,
    );
    expect(
      confirm.top - tester.getRect(find.text('Gone for good.')).bottom,
      24,
    );
    await tester.tap(find.byIcon(KunIcons.x));
    await tester.pumpAndSettle();

    showKunAlert(
      context,
      title: 'Delete?',
      message: 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(tester.getRect(panel).width, 368);
    await tester.tap(find.byIcon(KunIcons.x));
    await tester.pumpAndSettle();

    showKunAlert(context);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(
      tester
              .getRect(
                find.widgetWithText(
                  KunButton,
                  KunMessages.zhCN.alert.confirm,
                ),
              )
              .top -
          tester.getRect(panel).top,
      48,
    );
  });

  testWidgets('semantics alertDialog labelled with title or fallback',
      (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    try {
      BuildContext context = await pumpHost(tester);
      showKunAlert(context, title: 'Delete?', message: 'Gone for good.');
      await tester.pump();
      await tester.pumpAndSettle();

      SemanticsNode? dialog;
      void walk(SemanticsNode node) {
        if (node.getSemanticsData().role == SemanticsRole.alertDialog) {
          dialog = node;
        }
        node.visitChildren((SemanticsNode child) {
          walk(child);
          return true;
        });
      }

      walk(
        tester.binding.renderViews.first.owner!.semanticsOwner!
            .rootSemanticsNode!,
      );
      expect(dialog, isNotNull);
      expect(dialog!.getSemanticsData().label, 'Delete?');
      await tester.tap(find.byIcon(KunIcons.x));
      await tester.pumpAndSettle();

      context = await pumpHost(tester);
      showKunAlert(context, message: 'Gone for good.');
      await tester.pump();
      await tester.pumpAndSettle();
      dialog = null;
      walk(
        tester.binding.renderViews.first.owner!.semanticsOwner!
            .rootSemanticsNode!,
      );
      expect(dialog, isNotNull);
      expect(dialog!.getSemanticsData().label, KunMessages.zhCN.alert.title);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('scopes from the calling context reach the panel',
      (WidgetTester tester) async {
    setView(tester, const Size(1024, 768));
    BuildContext? saved;
    await tester.pumpWidget(
      wrap(
        KunTheme(
          data: KunThemeData.dark(),
          child: KunMessagesScope(
            messages: KunMessages.en,
            child: _Host(onReady: (BuildContext context) => saved = context),
          ),
        ),
      ),
    );
    await tester.pump();
    showKunAlert(saved!, title: 'Delete?', message: 'Gone for good.');
    await tester.pump();
    await tester.pumpAndSettle();
    final DecoratedBox box = tester.widget<DecoratedBox>(panel);
    expect((box.decoration as BoxDecoration).color, KunColors.dark.content1);
    expect(find.text('OK'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('external removal resolves false and a later call is fresh',
      (WidgetTester tester) async {
    final BuildContext context = await pumpHost(tester);
    final Future<bool> first = showKunAlert(
      context,
      title: 'First',
      message: 'One',
    );
    await tester.pump();
    await tester.pumpAndSettle();
    Navigator.popUntil(context, (Route<dynamic> route) => route.isFirst);
    await tester.pumpAndSettle();
    expect(await first, isFalse);
    expect(panel, findsNothing);

    final Future<bool> second = showKunAlert(
      context,
      title: 'Second',
      message: 'Two',
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Second'), findsOneWidget);
    await tester.tap(find.text(KunMessages.zhCN.alert.confirm));
    await tester.pumpAndSettle();
    expect(await second, isTrue);
  });

  testWidgets('keyboard open focuses cancel and Enter cancels',
      (WidgetTester tester) async {
    setView(tester, const Size(1024, 768));
    BuildContext? saved;
    await tester.pumpWidget(
      wrap(
        Stack(
          children: <Widget>[
            const KunModal(value: false, semanticLabel: 'host'),
            _Host(onReady: (BuildContext context) => saved = context),
          ],
        ),
        webKeys: true,
      ),
    );
    await tester.pump();
    final BuildContext context = saved!;
    await tester.sendKeyEvent(LogicalKeyboardKey.shift);
    await tester.pump();
    final Future<bool> result = showKunAlert(
      context,
      title: 'Delete?',
      message: 'Gone for good.',
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(
      Focus.of(tester.element(find.text(KunMessages.zhCN.alert.cancel)))
          .hasFocus,
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(await result, isFalse);
  });

  testWidgets('reduced motion shows and hides in one frame',
      (WidgetTester tester) async {
    setView(tester, const Size(1024, 768));
    BuildContext? saved;
    await tester.pumpWidget(
      wrap(
        _Host(onReady: (BuildContext context) => saved = context),
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
    final Future<bool> result = showKunAlert(
      saved!,
      title: 'Delete?',
      message: 'Gone for good.',
    );
    await tester.pump();
    expect(find.text('Delete?'), findsOneWidget);
    expect(layerOpacity(tester), 1);
    await tester.tap(find.text(KunMessages.zhCN.alert.confirm));
    await tester.pump();
    expect(await result, isTrue);
    expect(panel, findsNothing);
  });
}
