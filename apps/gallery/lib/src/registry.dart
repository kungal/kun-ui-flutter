import 'package:flutter/widgets.dart';

import 'registry.g.dart';

/// One addressable demo: the thing at `#/<component>/<slug>`.
class GalleryDemo {
  /// Creates a demo.
  const GalleryDemo({
    required this.slug,
    required this.title,
    required this.builder,
  });

  /// URL slug, lowercase with spaces as `-`.
  final String slug;

  /// Label on the index and in the registry.
  final String title;

  /// Builds the demo body.
  final WidgetBuilder builder;
}

/// One component's page on the index, and the demos under it.
class GalleryComponent {
  /// Creates a component entry.
  const GalleryComponent({
    required this.slug,
    required this.name,
    required this.demos,
  });

  /// URL slug, the widget name lowercased with no separator.
  final String slug;

  /// Widget name as shown on the index.
  final String name;

  /// Demos listed under this component, in index order.
  final List<GalleryDemo> demos;
}

/// The component whose [GalleryComponent.slug] is [slug], or null.
GalleryComponent? componentBySlug(String slug) {
  for (final GalleryComponent component in galleryComponents) {
    if (component.slug == slug) return component;
  }
  return null;
}

/// The demo at `#/<componentSlug>/<demoSlug>`, or null.
GalleryDemo? demoBySlug(String componentSlug, String demoSlug) {
  final GalleryComponent? component = componentBySlug(componentSlug);
  if (component == null) return null;
  for (final GalleryDemo demo in component.demos) {
    if (demo.slug == demoSlug) return demo;
  }
  return null;
}
