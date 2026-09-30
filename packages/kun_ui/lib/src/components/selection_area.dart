import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../foundation/design.dart';
import '../foundation/text_selection.dart';
import '../theme/theme.dart';

/// What a browser gives every run of text, without a look of its own: drag
/// to select, copy, and a right-click menu.
///
/// The web needs no such component, because the element is selectable by
/// default. Flutter widgets are not. [SelectableRegion] is the widgets-layer
/// machinery, and it needs selection controls and a context menu builder.
/// Material's SelectionArea supplies those from Material; this widget
/// supplies KunUI's handles and menu instead. Not part of the web contract.
///
/// The handles are [KunTextSelectionControls] in the primary solid, the
/// same paint a primary KunInput uses. The menu is the web's
/// KunContextMenu, labelled from KunMessages.textSelection, and it
/// captures KunTheme and KunMessagesScope from this region's context
/// so a theme inside a route still reaches a menu built in the root
/// overlay. There is no magnifier; the field has none either.
///
/// Flutter web is unchanged: with the browser's context menu enabled,
/// [SelectableRegion] shows the browser's menu, not KunUI's.
class KunSelectionArea extends StatefulWidget {
  /// Creates a selection area.
  const KunSelectionArea({
    super.key,
    required this.child,
    this.focusNode,
    this.onSelectionChanged,
    this.onSecondaryTapOutsideSelection,
  });

  /// The subtree this area makes selectable.
  final Widget child;

  /// {@macro flutter.widgets.Focus.focusNode}
  final FocusNode? focusNode;

  /// Called when the selected content changes.
  final ValueChanged<SelectedContent?>? onSelectionChanged;

  /// Called on a mouse right-click whose press does not land on the active
  /// selection, including when there is none. The area then shows no KunUI
  /// menu and leaves no text selected.
  ///
  /// An enclosing KunPressable never sees a right-click inside the area,
  /// because the area's recognizer wins the gesture arena, so an app
  /// passes this callback instead of KunPressable.onSecondaryTap.
  ///
  /// The call is made outside build, layout and paint, so the app can
  /// [State.setState] to open a KunContextMenu at the given global
  /// position.
  ///
  /// Null leaves [SelectableRegion]'s platform behaviour unchanged.
  final ValueChanged<Offset>? onSecondaryTapOutsideSelection;

  @override
  State<KunSelectionArea> createState() => _KunSelectionAreaState();
}

class _KunSelectionAreaState extends State<KunSelectionArea> {
  final GlobalKey<SelectableRegionState> _regionKey =
      GlobalKey<SelectableRegionState>();
  final _RecordingRegistrar _registrar = _RecordingRegistrar();

  bool _positionIsOnActiveSelection(Offset globalPosition) {
    for (final Selectable selectable in _registrar.selectables) {
      final Matrix4 transform = selectable.getTransformTo(null);
      for (final Rect rect in selectable.value.selectionRects) {
        if (MatrixUtils.transformRect(transform, rect)
            .contains(globalPosition)) {
          return true;
        }
      }
    }
    return false;
  }

  void _handleStolenSecondaryTap(Offset globalPosition) {
    final SelectableRegionState? region = _regionKey.currentState;
    region?.hideToolbar();
    region?.clearSelection();
    final ValueChanged<Offset>? callback =
        widget.onSecondaryTapOutsideSelection;
    if (callback == null) {
      return;
    }
    scheduleMicrotask(() => callback(globalPosition));
  }

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final Color primary = KunUIColor.primary.scaleOf(scheme).solid;
    // Mounted whether or not the callback is set, so setting it later does
    // not remount the app's subtree (a PopScope swap in KunChatLayout did).
    final Widget child = RawGestureDetector(
      excludeFromSemantics: true,
      behavior: HitTestBehavior.translucent,
      gestures: <Type, GestureRecognizerFactory>{
        _SecondaryTapOutsideRecognizer: GestureRecognizerFactoryWithHandlers<
            _SecondaryTapOutsideRecognizer>(
          () => _SecondaryTapOutsideRecognizer(
            debugOwner: this,
            onShouldSteal: (Offset globalPosition) =>
                widget.onSecondaryTapOutsideSelection != null &&
                !_positionIsOnActiveSelection(globalPosition),
            onStolen: _handleStolenSecondaryTap,
          ),
          (_SecondaryTapOutsideRecognizer instance) {},
        ),
      },
      child: Builder(
        builder: (BuildContext context) {
          _registrar.inner = SelectionContainer.maybeOf(context);
          return SelectionRegistrarScope(
            registrar: _registrar,
            child: widget.child,
          );
        },
      ),
    );
    return DefaultSelectionStyle(
      selectionColor: primary.withValues(alpha: 0.2),
      child: SelectableRegion(
        key: _regionKey,
        focusNode: widget.focusNode,
        selectionControls: KunTextSelectionControls(handleColor: primary),
        contextMenuBuilder: kunSelectableRegionContextMenu,
        onSelectionChanged: widget.onSelectionChanged,
        child: child,
      ),
    );
  }
}

class _SecondaryTapOutsideRecognizer extends OneSequenceGestureRecognizer {
  _SecondaryTapOutsideRecognizer({
    required this.onShouldSteal,
    required this.onStolen,
    super.debugOwner,
  }) : super(
          allowedButtonsFilter: (int buttons) =>
              buttons == kSecondaryMouseButton,
        );

  final bool Function(Offset globalPosition) onShouldSteal;
  final ValueChanged<Offset> onStolen;

  Offset? _downPosition;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _downPosition = event.position;
    if (onShouldSteal(event.position)) {
      resolve(GestureDisposition.accepted);
    } else {
      resolve(GestureDisposition.rejected);
    }
    stopTrackingPointer(event.pointer);
  }

  @override
  void handleEvent(PointerEvent event) {}

  @override
  void acceptGesture(int pointer) {
    final Offset? position = _downPosition;
    _downPosition = null;
    if (position != null) {
      onStolen(position);
    }
  }

  @override
  void rejectGesture(int pointer) {
    _downPosition = null;
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'secondary tap outside selection';
}

// Records every selectable the region's registrar receives and passes each
// one on unchanged. A nested SelectionContainer, which would have given the
// geometry through its delegate, made the fragments register inward, and a
// long press then selected nothing (SelectableRegion._selectWordAt never
// reached them).
class _RecordingRegistrar implements SelectionRegistrar {
  final Set<Selectable> selectables = <Selectable>{};
  SelectionRegistrar? _inner;

  set inner(SelectionRegistrar? value) {
    if (identical(value, _inner)) {
      return;
    }
    for (final Selectable selectable in selectables) {
      _inner?.remove(selectable);
      value?.add(selectable);
    }
    _inner = value;
  }

  @override
  void add(Selectable selectable) {
    selectables.add(selectable);
    _inner?.add(selectable);
  }

  @override
  void remove(Selectable selectable) {
    selectables.remove(selectable);
    _inner?.remove(selectable);
  }
}
