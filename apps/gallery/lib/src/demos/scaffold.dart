import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

Widget scaffoldBottomBar(BuildContext context) {
  final KunColorScheme scheme = KunTheme.of(context).colors;
  return SizedBox(
    width: 360,
    height: 640,
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.border),
        borderRadius: BorderRadius.circular(KunRadius.lg),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KunRadius.lg),
        child: const _BottomBarPhone(),
      ),
    ),
  );
}

class _BottomBarPhone extends StatefulWidget {
  const _BottomBarPhone();

  @override
  State<_BottomBarPhone> createState() => _BottomBarPhoneState();
}

class _BottomBarPhoneState extends State<_BottomBarPhone> {
  int _current = 0;

  static const List<({String label, IconData icon})> _destinations =
      <({String label, IconData icon})>[
    (label: 'Search', icon: KunIcons.search),
    (label: 'Calendar', icon: KunIcons.calendar),
    (label: 'Uploads', icon: KunIcons.upload),
  ];

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return KunScaffold(
      extendBody: true,
      bottomBar: Builder(
        builder: (BuildContext context) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.content1,
              border: Border(top: BorderSide(color: scheme.border)),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom,
              ),
              child: Row(
                children: <Widget>[
                  for (int i = 0; i < _destinations.length; i++)
                    Expanded(
                      child: KunNavItem(
                        label: _destinations[i].label,
                        icon: Icon(_destinations[i].icon),
                        stacked: true,
                        current: _current == i,
                        onPressed: () => setState(() => _current = i),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
      body: Builder(
        builder: (BuildContext context) {
          return ListView.builder(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom,
            ),
            itemCount: 20,
            itemBuilder: (BuildContext context, int index) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  KunSpacing.unit * 4,
                  KunSpacing.unit * 2,
                  KunSpacing.unit * 4,
                  KunSpacing.unit * 2,
                ),
                child: KunCard(
                  padding: KunCardPadding.md,
                  child: Text('Card ${index + 1}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
