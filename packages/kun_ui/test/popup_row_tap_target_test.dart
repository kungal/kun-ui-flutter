import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Widget wrap(Widget child, KunTapTargetSize tapTargetSize) => KunTheme(
      data: KunThemeData.light(tapTargetSize: tapTargetSize),
      child: WidgetsApp(
        color: KunColors.black,
        debugShowCheckedModeBanner: false,
        home: Align(alignment: Alignment.topLeft, child: child),
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

typedef Case = (TargetPlatform, KunTapTargetSize, double);

List<Case> cases(double web) => <Case>[
      (TargetPlatform.android, KunTapTargetSize.adaptive, 48),
      (TargetPlatform.iOS, KunTapTargetSize.adaptive, 44),
      (TargetPlatform.linux, KunTapTargetSize.adaptive, web),
      (TargetPlatform.android, KunTapTargetSize.shrinkWrap, web),
    ];

/// Pumps [child] under each case, opens it, and measures [row] and the fill
/// drawn behind it.
Future<void> expectRowHeights(
  WidgetTester tester, {
  required Widget child,
  required Future<void> Function(WidgetTester tester) open,
  required Finder row,
  required List<Case> under,
}) async {
  setView(tester);
  try {
    for (final (TargetPlatform platform, KunTapTargetSize size, double height)
        in under) {
      debugDefaultTargetPlatformOverride = platform;
      await tester.pumpWidget(
        wrap(KeyedSubtree(key: UniqueKey(), child: child), size),
      );
      await open(tester);
      final String at = '$platform, ${size.name}';
      expect(tester.getSize(row).height, height, reason: at);
      expect(
        tester
            .getSize(
              find
                  .descendant(of: row, matching: find.byType(DecoratedBox))
                  .first,
            )
            .height,
        height,
        reason: '$at: the fill covers the whole row',
      );
    }
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void setView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

const List<KunMenuEntry> menuItems = <KunMenuEntry>[
  KunContextMenuItem(key: 'edit', label: 'Edit'),
  KunContextMenuItem(
    key: 'mute',
    label: 'Mute',
    children: <KunMenuEntry>[
      KunContextMenuItem(key: 'hour', label: '1 hour'),
      KunContextMenuItem(key: 'day', label: '1 day'),
    ],
  ),
  KunMenuSeparator(),
  KunContextMenuItem(key: 'delete', label: 'Delete'),
];

Future<void> settle(WidgetTester tester) => tester.pumpAndSettle();

void main() {
  testWidgets('KunDropdown rows meet the platform on phones', (tester) async {
    await expectRowHeights(
      tester,
      child: const KunDropdown(
        items: menuItems,
        trigger: SizedBox(width: 80, height: 32, child: Text('actions')),
      ),
      open: (WidgetTester tester) async {
        await tester.tap(find.text('actions'));
        await tester.pumpAndSettle();
      },
      row: find.byKey(const ValueKey<String>('KunDropdown.item.edit')),
      under: cases(32),
    );
  });

  testWidgets('a submenu opened by a tap has the same rows', (tester) async {
    await expectRowHeights(
      tester,
      child: const KunDropdown(
        items: menuItems,
        trigger: SizedBox(width: 80, height: 32, child: Text('actions')),
      ),
      open: (WidgetTester tester) async {
        await tester.tap(find.text('actions'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mute'));
        await tester.pumpAndSettle();
      },
      row: find.byKey(const ValueKey<String>('KunDropdown.item.hour')),
      under: <Case>[
        for (final Case c in cases(32))
          if (c.$1 != TargetPlatform.linux) c,
      ],
    );
  });

  testWidgets('KunContextMenu rows meet the platform on phones',
      (tester) async {
    await expectRowHeights(
      tester,
      child: KunContextMenu(
        visible: true,
        items: menuItems,
        position: const Offset(20, 20),
        onClose: () {},
      ),
      open: settle,
      row: find.byKey(const ValueKey<String>('KunContextMenu.item.delete')),
      under: cases(32),
    );
  });

  testWidgets('KunChatMessageMenu rows meet the platform on phones',
      (tester) async {
    await expectRowHeights(
      tester,
      child: KunChatMessageMenu(
        visible: true,
        actions: const <KunChatMessageAction>[
          KunChatMessageAction.reply,
          KunChatMessageAction.copy,
        ],
        position: const Offset(20, 20),
        onClose: () {},
      ),
      open: settle,
      row: find.byKey(const ValueKey<String>('KunChatMessageMenu.item.reply')),
      under: cases(32),
    );
  });

  testWidgets('KunCommandPalette results meet the platform on phones',
      (tester) async {
    await expectRowHeights(
      tester,
      child: KunCommandPalette(
        open: true,
        onOpenChanged: (bool open) {},
        items: const <KunCommandGroup>[
          KunCommandGroup(
            items: <KunCommandItem>[
              KunCommandItem(value: 'settings', label: 'Settings'),
            ],
          ),
        ],
      ),
      open: settle,
      row:
          find.byKey(const ValueKey<String>('KunCommandPalette.item.settings')),
      under: cases(36),
    );
  });

  testWidgets('KunSelect options meet the platform on phones', (tester) async {
    await expectRowHeights(
      tester,
      child: SizedBox(
        width: 240,
        child: KunSelect<String, KunSelectOption<String>>(
          options: const <KunSelectOption<String>>[
            KunSelectOption<String>(value: 'pc', label: 'PC'),
            KunSelectOption<String>(value: 'switch', label: 'Switch'),
          ],
          value: null,
          onChanged: (String? value) {},
        ),
      ),
      open: (WidgetTester tester) async {
        await tester
            .tap(find.byKey(const ValueKey<String>('KunSelect.chevron')));
        await tester.pumpAndSettle();
      },
      row: find.byKey(const ValueKey<String>('KunSelect.option.0')),
      under: cases(36),
    );
  });
}
