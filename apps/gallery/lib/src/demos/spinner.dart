import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

Widget spinnerSizes(BuildContext context) {
  return const Row(
    mainAxisAlignment: MainAxisAlignment.center,
    spacing: 24,
    children: [
      KunSpinner(size: 14),
      KunSpinner(size: 24),
      KunSpinner(size: 48),
    ],
  );
}
