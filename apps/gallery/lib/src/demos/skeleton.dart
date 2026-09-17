import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

Widget skeletonBasic(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: KunContainerWidths.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: KunSpacing.unit * 3,
        children: [
          KunSkeleton(variant: KunSkeletonVariant.text, widthFactor: 0.6),
          KunSkeleton(variant: KunSkeletonVariant.text),
          KunSkeleton(variant: KunSkeletonVariant.text, widthFactor: 0.8),
        ],
      ),
    ),
  );
}

Widget skeletonShapes(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: KunContainerWidths.sm),
      child: Row(
        spacing: KunSpacing.unit * 4,
        children: const [
          KunSkeleton(
            variant: KunSkeletonVariant.circle,
            height: KunSpacing.unit * 12,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: KunSpacing.unit * 2,
              children: [
                KunSkeleton(
                  variant: KunSkeletonVariant.text,
                  widthFactor: 0.4,
                ),
                KunSkeleton(
                  variant: KunSkeletonVariant.text,
                  widthFactor: 0.7,
                ),
              ],
            ),
          ),
          KunSkeleton(
            variant: KunSkeletonVariant.rect,
            width: KunSpacing.unit * 20,
            height: KunSpacing.unit * 12,
          ),
        ],
      ),
    ),
  );
}

Widget skeletonLoaded(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _SkeletonLoaded(),
  );
}

Widget skeletonVariants(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 5,
      children: [
        for (final KunSkeletonVariant variant in KunSkeletonVariant.values)
          for (final KunSkeletonAnimation animation
              in KunSkeletonAnimation.values)
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: KunSpacing.unit * 2,
              children: [
                Text('${variant.name} · ${animation.name}'),
                Wrap(
                  spacing: KunSpacing.unit * 3,
                  runSpacing: KunSpacing.unit * 3,
                  children: [
                    for (final KunUIRounded? rounded in <KunUIRounded?>[
                      null,
                      ...KunUIRounded.values,
                    ])
                      SizedBox(
                        width: KunSpacing.unit * 20,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: KunSpacing.unit * 1,
                          children: [
                            Text(rounded?.name ?? 'null'),
                            KunSkeleton(
                              variant: variant,
                              rounded: rounded,
                              animation: animation,
                              height: KunSpacing.unit * 6,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
      ],
    ),
  );
}

class _SkeletonLoaded extends StatefulWidget {
  const _SkeletonLoaded();

  @override
  State<_SkeletonLoaded> createState() => _SkeletonLoadedState();
}

class _SkeletonLoadedState extends State<_SkeletonLoaded> {
  bool _loaded = false;

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: KunContainerWidths.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: KunSpacing.unit * 4,
        children: [
          KunButton(
            size: KunUISize.sm,
            onPressed: () => setState(() => _loaded = !_loaded),
            child: Text(_loaded ? '重新加载' : '完成加载'),
          ),
          KunSkeleton(
            loaded: _loaded,
            variant: KunSkeletonVariant.rect,
            height: KunSpacing.unit * 16,
            child: SizedBox(
              width: double.infinity,
              child: KunCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '内容已就绪',
                      style: TextStyle(fontWeight: KunFontWeights.medium),
                    ),
                    Text(
                      'loaded 为 true 时渲染默认插槽。',
                      style:
                          KunText.sm.copyWith(color: scheme.neutral.shade500),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
