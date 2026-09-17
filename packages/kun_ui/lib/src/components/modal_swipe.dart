part of 'modal.dart';

bool _scrollBlocksSwipe(ScrollPosition position) {
  if (!position.hasPixels || position.axis != Axis.vertical) {
    return false;
  }
  return (position.pixels - position.minScrollExtent).abs() >
          precisionErrorTolerance ||
      position.isScrollingNotifier.value;
}

/// KunInput's [RenderEditable] sets `rendererIgnoresPointer`, so it is not
/// itself on the hit path — only the selection detector wrapping it is.
bool _hitPathStartsOnEditable(HitTestResult result) {
  for (final HitTestEntry entry in result.path) {
    final HitTestTarget target = entry.target;
    if (target is RenderEditable) {
      return true;
    }
    if (target is RenderObject) {
      bool found = false;
      target.visitChildren((RenderObject child) {
        if (child is RenderEditable) {
          found = true;
        }
      });
      if (found) {
        return true;
      }
    }
  }
  return false;
}

List<ScrollPosition> _verticalScrollsAt(BuildContext? root, Offset global) {
  final List<ScrollPosition> found = <ScrollPosition>[];
  void visit(Element element) {
    if (element is StatefulElement && element.state is ScrollableState) {
      final ScrollPosition position =
          (element.state as ScrollableState).position;
      final RenderObject? box = element.renderObject;
      if (position.axis == Axis.vertical &&
          box is RenderBox &&
          box.hasSize &&
          (Offset.zero & box.size).contains(box.globalToLocal(global))) {
        found.add(position);
      }
    }
    element.visitChildren(visit);
  }

  root?.visitChildElements(visit);
  return found;
}

HitTestResult _hitTestAt(Offset global, int viewId) {
  final HitTestResult result = HitTestResult();
  WidgetsBinding.instance.hitTestInView(result, global, viewId);
  return result;
}

/// The web's `DRAG_START_THRESHOLD`, which it keeps under the browser's touch
/// slop so the sheet decides before the page commits to a scroll.
const double _swipeDecisionDistance = 6;

// A Listener that decided at kTouchSlop lost the first move to a scroll view's
// drag recognizer, so the content scrolled or bounced under a claimed swipe.
// This one decides under the slop and wins the arena. The page's Listener
// calls [decide] before the gesture binding routes the move, so a single move
// past both thresholds still reaches this recognizer first.
class _KunSwipeRecognizer extends OneSequenceGestureRecognizer {
  _KunSwipeRecognizer({super.debugOwner});

  bool Function(Offset position)? canStart;
  bool Function(Offset origin, int viewId)? canClaim;
  VoidCallback? onClaim;
  ValueChanged<double>? onUpdate;
  ValueChanged<double>? onEnd;
  VoidCallback? onCancel;

  int? _pointer;
  int _viewId = 0;
  Offset _origin = Offset.zero;
  bool _claimed = false;
  VelocityTracker? _tracker;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      _pointer == null &&
      super.isPointerAllowed(event) &&
      (canStart?.call(event.position) ?? false);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _pointer = event.pointer;
    _viewId = event.viewId;
    _origin = event.position;
    _claimed = false;
    _tracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.position);
    super.addAllowedPointer(event);
  }

  void decide(PointerMoveEvent event) {
    if (event.pointer != _pointer || _claimed) {
      return;
    }
    final Offset delta = event.position - _origin;
    if (delta.dx.abs() < _swipeDecisionDistance &&
        delta.dy.abs() < _swipeDecisionDistance) {
      return;
    }
    if (delta.dx.abs() > delta.dy.abs() ||
        delta.dy <= 0 ||
        !(canClaim?.call(_origin, _viewId) ?? false)) {
      _finish(event.pointer);
      return;
    }
    resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    if (event is PointerMoveEvent) {
      _tracker?.addPosition(event.timeStamp, event.position);
      decide(event);
      if (_claimed) {
        onUpdate?.call((event.position - _origin).dy);
      }
    } else if (event is PointerUpEvent) {
      if (_claimed) {
        onEnd?.call(_tracker?.getVelocity().pixelsPerSecond.dy ?? 0);
      }
      _finish(event.pointer);
    } else if (event is PointerCancelEvent) {
      if (_claimed) {
        onCancel?.call();
      }
      _finish(event.pointer);
    }
  }

  void _finish(int pointer) {
    if (!_claimed) {
      resolve(GestureDisposition.rejected);
    }
    stopTrackingPointer(pointer);
  }

  @override
  void acceptGesture(int pointer) {
    if (pointer != _pointer || _claimed) {
      return;
    }
    _claimed = true;
    onClaim?.call();
  }

  @override
  void rejectGesture(int pointer) {
    if (pointer == _pointer) {
      stopTrackingPointer(pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _pointer = null;
    _claimed = false;
    _tracker = null;
  }

  @override
  String get debugDescription => 'KunModal swipe';
}
