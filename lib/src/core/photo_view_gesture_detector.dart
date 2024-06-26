import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'photo_view_hit_corners.dart';

const double _kPopDistance = 50;

class PhotoViewGestureDetector extends StatelessWidget {
  PhotoViewGestureDetector({
    Key? key,
    this.maxScale,
    this.minScale,
    this.hitDetector,
    this.onScaleStart,
    this.onScaleUpdate,
    this.onScaleEnd,
    this.onDoubleTap,
    this.child,
    this.onTapUp,
    this.onTapDown,
    this.behavior,
    this.transformationController,
    this.onScaleChanged,
  }) : super(key: key);

  final dynamic maxScale;
  final dynamic minScale;
  final TransformationController? transformationController;
  final GestureDoubleTapCallback? onDoubleTap;
  final HitCornersDetector? hitDetector;

  final GestureScaleStartCallback? onScaleStart;
  final GestureScaleUpdateCallback? onScaleUpdate;
  final GestureScaleEndCallback? onScaleEnd;
  final void Function(double)? onScaleChanged;

  final GestureTapUpCallback? onTapUp;
  final GestureTapDownCallback? onTapDown;

  final Widget? child;

  final HitTestBehavior? behavior;

  Offset _startScaleOffset = const Offset(0, 0);
  Offset _endScaleOffset = const Offset(0, 0);
  int _startPointerCount = 0;
  int _endPointerCount = 0;

  @override
  Widget build(BuildContext context) {
    final scope = PhotoViewGestureDetectorScope.of(context);

    final Axis? axis = scope?.axis;

    final Map<Type, GestureRecognizerFactory> gestures =
        <Type, GestureRecognizerFactory>{};

    if (onTapDown != null || onTapUp != null) {
      gestures[TapGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
        () => TapGestureRecognizer(debugOwner: this),
        (TapGestureRecognizer instance) {
          instance
            ..onTapDown = onTapDown
            ..onTapUp = onTapUp;
        },
      );
    }

    gestures[DoubleTapGestureRecognizer] =
        GestureRecognizerFactoryWithHandlers<DoubleTapGestureRecognizer>(
      () => DoubleTapGestureRecognizer(debugOwner: this),
      (DoubleTapGestureRecognizer instance) {
        instance..onDoubleTap = onDoubleTap;
      },
    );

    // if (Platform.isAndroid) {
    //   gestures[PhotoViewGestureRecognizer] =
    //       GestureRecognizerFactoryWithHandlers<PhotoViewGestureRecognizer>(
    //     () => PhotoViewGestureRecognizer(
    //         hitDetector: hitDetector, debugOwner: this, validateAxis: axis),
    //     (PhotoViewGestureRecognizer instance) {
    //       instance
    //         ..dragStartBehavior = DragStartBehavior.start
    //         ..onStart = onScaleStart
    //         ..onUpdate = onScaleUpdate
    //         ..onEnd = onScaleEnd;
    //     },
    //   );
    //
    //   return RawGestureDetector(
    //     behavior: behavior,
    //     child: child,
    //     gestures: gestures,
    //   );
    // }

    return InteractiveViewer(
      key: const Key('photo_interactive_viewer'),
      minScale: minScale,
      maxScale: maxScale,
      transformationController: transformationController,
      onInteractionStart: onInteractionStart,
      onInteractionUpdate: (ScaleUpdateDetails details) {
        onInteractionUpdate(details);
      },
      onInteractionEnd: (ScaleEndDetails details) {
        onInteractionEnd(details, context);
      },
      child: RawGestureDetector(
        behavior: behavior,
        child: child,
        gestures: gestures,
      ),
    );
  }

  void onInteractionStart(ScaleStartDetails details) {
    // print('----onInteractionStart---${details}');
    _startScaleOffset = details.focalPoint;
    _startPointerCount = details.pointerCount;
  }

  void onInteractionUpdate(ScaleUpdateDetails details) {
    // print('----onInteractionUpdate---${details}');
    _endScaleOffset = details.focalPoint;
    _endPointerCount = details.pointerCount;
  }

  void onInteractionEnd(ScaleEndDetails details, BuildContext context) {
    // print('----onInteractionEnd---${details}');
    double scale = transformationController?.value.getMaxScaleOnAxis() ?? 1.0;
    if (onScaleChanged != null) {
      onScaleChanged!(scale);
    }

    final distance = _endScaleOffset.dy - _startScaleOffset.dy;
    final scaleFixed = scale.toStringAsFixed(3);

    final originalScaleFixed = 1.0.toStringAsFixed(1);
    if (scaleFixed.contains(originalScaleFixed)) {
      scale = 1.0;
    }
    if (scale == 1.0 && _startPointerCount == 1 && _endPointerCount == 1 && distance > _kPopDistance) {
      Navigator.of(context).pop();
    }
  }
}

class PhotoViewGestureRecognizer extends ScaleGestureRecognizer {
  PhotoViewGestureRecognizer({
    this.hitDetector,
    Object? debugOwner,
    this.validateAxis,
    PointerDeviceKind? kind,
  }) : super(debugOwner: debugOwner);
  final HitCornersDetector? hitDetector;
  final Axis? validateAxis;

  Map<int, Offset> _pointerLocations = <int, Offset>{};

  Offset? _initialFocalPoint;
  Offset? _currentFocalPoint;

  bool ready = true;

  @override
  void addAllowedPointer(event) {
    if (ready) {
      ready = false;
      _pointerLocations = <int, Offset>{};
    }
    super.addAllowedPointer(event);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    ready = true;
    super.didStopTrackingLastPointer(pointer);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (validateAxis != null) {
      _computeEvent(event);
      _updateDistances();
      _decideIfWeAcceptEvent(event);
    }
    super.handleEvent(event);
  }

  void _computeEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      if (!event.synthesized) {
        _pointerLocations[event.pointer] = event.position;
      }
    } else if (event is PointerDownEvent) {
      _pointerLocations[event.pointer] = event.position;
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pointerLocations.remove(event.pointer);
    }

    _initialFocalPoint = _currentFocalPoint;
  }

  void _updateDistances() {
    final int count = _pointerLocations.keys.length;
    Offset focalPoint = Offset.zero;
    for (int pointer in _pointerLocations.keys)
      focalPoint += _pointerLocations[pointer]!;
    _currentFocalPoint =
        count > 0 ? focalPoint / count.toDouble() : Offset.zero;
  }

  void _decideIfWeAcceptEvent(PointerEvent event) {
    if (!(event is PointerMoveEvent)) {
      return;
    }
    final move = _initialFocalPoint! - _currentFocalPoint!;
    final bool shouldMove = hitDetector!.shouldMove(move, validateAxis!);
    if (shouldMove || _pointerLocations.keys.length > 1) {
      acceptGesture(event.pointer);
    }
  }
}

/// An [InheritedWidget] responsible to give a axis aware scope to [PhotoViewGestureRecognizer].
///
/// When using this, PhotoView will test if the content zoomed has hit edge every time user pinches,
/// if so, it will let parent gesture detectors win the gesture arena
///
/// Useful when placing PhotoView inside a gesture sensitive context,
/// such as [PageView], [Dismissible], [BottomSheet].
///
/// Usage example:
/// ```
/// PhotoViewGestureDetectorScope(
///   axis: Axis.vertical,
///   child: PhotoView(
///     imageProvider: AssetImage("assets/pudim.jpg"),
///   ),
/// );
/// ```
class PhotoViewGestureDetectorScope extends InheritedWidget {
  PhotoViewGestureDetectorScope({
    this.axis,
    required Widget child,
  }) : super(child: child);

  static PhotoViewGestureDetectorScope? of(BuildContext context) {
    final PhotoViewGestureDetectorScope? scope = context
        .dependOnInheritedWidgetOfExactType<PhotoViewGestureDetectorScope>();
    return scope;
  }

  final Axis? axis;

  @override
  bool updateShouldNotify(PhotoViewGestureDetectorScope oldWidget) {
    return axis != oldWidget.axis;
  }
}
