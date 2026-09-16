import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

Widget nullDefault(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: KunNull(),
  );
}

Widget nullCustom(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: KunSpacing.unit * 5,
      children: [
        Text('isShowSticker: false'),
        KunNull(
          description: '这里什么都没有',
          isShowSticker: false,
        ),
        Text('custom image'),
        KunNull(
          image: KunImages.avatarFallback,
          description: 'A custom image',
        ),
      ],
    ),
  );
}
