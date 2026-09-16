import 'package:flutter/widgets.dart';
import 'package:kun_ui_icons/kun_ui_icons.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../locale/messages.dart';
import '../theme/theme.dart';

/// An empty-state placeholder implementing the web `KunNull` contract.
///
/// The default image is bundled, so nothing is fetched. The image is
/// decorative to assistive technology.
class KunNull extends StatelessWidget {
  /// Creates an empty-state placeholder.
  const KunNull({
    super.key,
    this.description,
    this.isShowSticker = true,
    this.image = KunImages.nullImage,
  });

  /// The empty-state line.
  ///
  /// Null resolves to the locale's `nullState.description`; an empty string
  /// stays empty.
  final String? description;

  /// Whether to show the mascot image (web `isShowSticker`).
  final bool isShowSticker;

  /// The mascot (web `src`). Defaults to the bundled [KunImages.nullImage].
  final ImageProvider image;

  @override
  Widget build(BuildContext context) {
    final scheme = KunTheme.of(context).colors;
    final resolvedDescription =
        description ?? KunMessagesScope.of(context).nullState.description;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: KunSpacing.unit * 3,
        children: [
          if (isShowSticker)
            ClipRRect(
              borderRadius: BorderRadius.circular(KunRadius.lg),
              child: Image(
                image: image,
                width: KunSpacing.unit * 72,
                excludeFromSemantics: true,
              ),
            ),
          Text(
            resolvedDescription,
            style: TextStyle(color: scheme.neutral.shade500),
          ),
        ],
      ),
    );
  }
}
