// Minimal-arena reproduction of the iOS-only webtoon scroll freeze.
//
// GOAL: reproduce, in a local Flutter widget test (no iOS device), the reader
// bug where a single-finger vertical drag will NOT scroll the vertical webtoon
// list on iOS (tap-to-page still works, disabling pinch-zoom fixes it) while
// Android scrolls fine.
//
// ARCHITECTURE being modelled (see multichapter_continuous_reader_mode.dart):
//   OUTER  DirectionalSwipeGestureHandler -> RawGestureDetector with our
//          SingleTouch{Pan,Horizontal,Vertical} drag recognizers (chapter-
//          boundary swipe). ANCESTOR of the ZoomView.
//   INNER  ZoomView -> a GestureDetector with onScale{Start,Update,End} whose
//          ScaleGestureRecognizer re-synthesizes scroll into
//          position.drag(); plus a Listener that, when forceHoldOnPointerDown
//          is true, calls position.hold() on EVERY finger-down.
//
// HYPOTHESIS: the outer single-touch drag recognizer and the inner scale
// recognizer resolve the arena differently on iOS vs Android for a single
// finger vertical drag. If the scale recognizer LOSES, onScaleStart never
// fires, position.drag() is never created, and the position stays FROZEN in
// the hold() that forceHoldOnPointerDown installed on pointer-down. Net: no
// scroll on iOS.
//
// This test strips to the essential arena: the same recognizers, a real
// ScrollController driven exactly like ZoomView does, and the same
// forceHoldOnPointerDown hold(). We drive a single-finger vertical drag under
// debugDefaultTargetPlatformOverride = iOS vs Android and assert whether the
// scroll offset moves.

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tsumiru/src/constants/enum.dart';
import 'package:tsumiru/src/features/manga_book/domain/chapter_page/chapter_page_model.dart';
import 'package:tsumiru/src/features/manga_book/presentation/reader/widgets/directional_swipe_gesture_handler.dart';
import 'package:tsumiru/src/widgets/zoom/single_touch_drag_recognizers.dart';

/// A widget that reproduces the ZoomView core gesture wiring against a real
/// scrollable list, wrapped by the outer single-touch drag recognizers.
///
/// [forceHoldOnPointerDown] mirrors ZoomView's option: hold() the position on
/// every pointer-down. [useAdvancedGestures] switches between the outer
/// handler's two variants (Pan vs Horizontal+Vertical).
class MinimalArena extends StatefulWidget {
  const MinimalArena({
    super.key,
    required this.controller,
    required this.forceHoldOnPointerDown,
    required this.useAdvancedGestures,
    this.disableOuterHandler = false,
    this.onScaleStartFired,
    this.onOuterSwipeEnd,
    this.onScaleUpdateDelta,
    this.onOffsetApplied,
    this.onScaleFactor,
  });

  final ScrollController controller;
  final bool forceHoldOnPointerDown;
  final bool useAdvancedGestures;
  final bool disableOuterHandler;
  final VoidCallback? onScaleStartFired;
  final VoidCallback? onOuterSwipeEnd;
  final ValueChanged<double>? onScaleUpdateDelta;
  final ValueChanged<double>? onOffsetApplied;
  // Reports the raw scale factor from each onScaleUpdate — used to prove a
  // two-finger pinch still reaches ZoomView's scale recognizer (i.e. pinch-zoom
  // is preserved) even with the outer swipe handler present.
  final ValueChanged<double>? onScaleFactor;

  @override
  State<MinimalArena> createState() => _MinimalArenaState();
}

class _MinimalArenaState extends State<MinimalArena> {
  Drag? _drag;
  // Held on pointer-down when forceHoldOnPointerDown is true, mirroring
  // ZoomView. Intentionally only assigned (holding the position), never read —
  // the freeze IS the leftover hold, so keeping the reference is the point.
  // ignore: unused_field
  ScrollHoldController? _hold;

  // ---- ZoomView _TouchHandler equivalent (copied semantics) ----
  void _handleDragStart(DragStartDetails details) {
    _drag = widget.controller.position.drag(details, () => _drag = null);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    _drag?.update(details);
  }

  void _handleDragEnd(DragEndDetails details) {
    _drag?.end(details);
  }

  // ---- Outer handler: the DirectionalSwipeGestureHandler recognizers ----
  Map<Type, GestureRecognizerFactory> _outerGestures() {
    if (widget.useAdvancedGestures) {
      return <Type, GestureRecognizerFactory>{
        SingleTouchPanGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<SingleTouchPanGestureRecognizer>(
          () => SingleTouchPanGestureRecognizer(debugOwner: this),
          (r) {
            r.onEnd = (_) => widget.onOuterSwipeEnd?.call();
          },
        ),
      };
    }
    return <Type, GestureRecognizerFactory>{
      SingleTouchHorizontalDragGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<
              SingleTouchHorizontalDragGestureRecognizer>(
        () => SingleTouchHorizontalDragGestureRecognizer(debugOwner: this),
        (r) {
          r.onEnd = (_) => widget.onOuterSwipeEnd?.call();
        },
      ),
      SingleTouchVerticalDragGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<
              SingleTouchVerticalDragGestureRecognizer>(
        () => SingleTouchVerticalDragGestureRecognizer(debugOwner: this),
        (r) {
          r.onEnd = (_) => widget.onOuterSwipeEnd?.call();
        },
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    // The list itself, with all drag inputs disabled exactly like ZoomView's
    // ScrollConfiguration(dragDevices: {}) so ONLY our synthesized drag can
    // move it.
    final list = ScrollConfiguration(
      behavior: const ScrollBehavior().copyWith(
        overscroll: false,
        dragDevices: <PointerDeviceKind>{},
        scrollbars: false,
      ),
      child: ListView.builder(
        controller: widget.controller,
        physics: const ClampingScrollPhysics(),
        itemCount: 500,
        itemBuilder: (context, i) => SizedBox(
          height: 100,
          child: Center(child: Text('item $i')),
        ),
      ),
    );

    // INNER: ZoomView's Listener (forceHoldOnPointerDown) + GestureDetector
    // (scale recognizer that synthesizes the drag).
    final inner = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerUp: (_) {},
      onPointerDown: widget.forceHoldOnPointerDown
          ? (_) {
              _hold = widget.controller.position.hold(() => _hold = null);
            }
          : null,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onScaleStart: (ScaleStartDetails details) {
          widget.onScaleStartFired?.call();
          if (details.pointerCount == 1) {
            _handleDragStart(DragStartDetails(
              globalPosition: details.focalPoint,
              kind: PointerDeviceKind.touch,
            ));
          }
        },
        onScaleUpdate: (ScaleUpdateDetails details) {
          widget.onScaleFactor?.call(details.scale);
          // A real multi-finger pinch (pointerCount > 1) drives ZoomView's
          // scale/zoom path, not the single-finger pan path — don't synthesize
          // a scroll drag for it.
          if (details.pointerCount > 1) return;
          // pan branch (single finger): synthesize vertical drag update
          final delta = details.focalPointDelta;
          final before = widget.controller.offset;
          _handleDragUpdate(DragUpdateDetails(
            globalPosition: details.focalPoint,
            sourceTimeStamp: details.sourceTimeStamp,
            primaryDelta: delta.dy,
            delta: Offset(0.0, delta.dy),
          ));
          final after = widget.controller.offset;
          // Report the scale delta AND the actual offset applied, so we can see
          // where a per-update 2x factor enters.
          widget.onScaleUpdateDelta?.call(delta.dy);
          widget.onOffsetApplied?.call(after - before);
        },
        onScaleEnd: (ScaleEndDetails details) {
          _handleDragEnd(DragEndDetails(
            velocity: Velocity(
                pixelsPerSecond:
                    Offset(0.0, details.velocity.pixelsPerSecond.dy)),
            primaryVelocity: details.velocity.pixelsPerSecond.dy,
          ));
        },
        child: list,
      ),
    );

    // OUTER: the swipe handler wraps the inner ZoomView.
    final Widget wrapped = widget.disableOuterHandler
        ? inner
        : RawGestureDetector(
            behavior: HitTestBehavior.translucent,
            gestures: _outerGestures(),
            child: inner,
          );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(400, 800)),
        child: wrapped,
      ),
    );
  }
}

/// Perform a single-finger vertical drag and return how far the list scrolled.
class _DragResult {
  _DragResult(this.offsetDuringDrag, this.offsetAfterSettle, this.physicsType);
  final double offsetDuringDrag; // offset right before finger-up (no fling)
  final double offsetAfterSettle; // offset after settle/fling animation
  final String physicsType;
}

Future<_DragResult> _singleFingerVerticalDrag(
  WidgetTester tester, {
  required ScrollController controller,
  double dy = -300, // drag up => scroll down (positive offset)
  double jitterDx = 0, // per-step horizontal jitter to mimic a real finger
}) async {
  final start = tester.getCenter(find.byType(ListView));
  final gesture = await tester.startGesture(start);
  // Move in several increments the way a real finger does, so slop is crossed
  // gradually and the arena resolves on movement, not one teleport.
  const steps = 15;
  for (int i = 0; i < steps; i++) {
    // Alternate the jitter sign so net horizontal travel stays ~0 but each
    // event carries a horizontal component (a real thumb is never axis-pure).
    final dx = jitterDx * (i.isEven ? 1 : -1);
    await gesture.moveBy(Offset(dx, dy / steps));
    await tester.pump(const Duration(milliseconds: 16));
  }
  final duringDrag = controller.offset;
  final physicsType =
      controller.hasClients ? controller.position.physics.runtimeType.toString() : 'none';
  await gesture.up();
  await tester.pumpAndSettle(const Duration(milliseconds: 50));
  return _DragResult(duringDrag, controller.offset, physicsType);
}

/// Two-finger pinch (fingers move apart). The harness reports each
/// onScaleUpdate scale factor via onScaleFactor; a value > 1 means the pinch
/// reached ZoomView's scale recognizer — i.e. pinch-zoom is alive.
Future<void> _twoFingerPinch(WidgetTester tester) async {
  final center = tester.getCenter(find.byType(ListView));
  final f1 = await tester.startGesture(center + const Offset(-20, 0));
  final f2 = await tester.startGesture(center + const Offset(20, 0));
  for (int i = 0; i < 10; i++) {
    await f1.moveBy(const Offset(-8, 0));
    await f2.moveBy(const Offset(8, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await f1.up();
  await f2.up();
  await tester.pumpAndSettle(const Duration(milliseconds: 50));
}

/// Builds the REAL DirectionalSwipeGestureHandler for [axis] with the default
/// reader config (SIMPLE handler: swipeToggle on, lastPageSwipe off).
DirectionalSwipeGestureHandler _realHandler(Axis axis) =>
    DirectionalSwipeGestureHandler(
      scrollDirection: axis,
      readerSwipeChapterToggle: true,
      lastPageSwipeEnabled: false,
      resolvedReaderMode: axis == Axis.vertical
          ? ReaderMode.webtoon
          : ReaderMode.singleHorizontalLTR,
      currentIndex: 0,
      chapterPages: ChapterPagesDto(
        chapter: ChapterPagesChapterDto(id: 1, pageCount: 3),
        pages: const ['a', 'b', 'c'],
      ),
      mangaId: 1,
      prevNextChapterPair: null,
      onTap: () {},
      onLongPressStart: (_) {},
      onLongPressEnd: (_) {},
      onLongPressMoveUpdate: (_) {},
      onNextPage: () {},
      onPreviousPage: () {},
      pageController: null,
      child: const SizedBox(width: 200, height: 400),
    );

/// True if any RawGestureDetector in the tree installs one of our SingleTouch*
/// swipe recognizers (the ones that steal the single-finger drag from ZoomView).
bool _hasSingleTouchRecognizer(WidgetTester tester) {
  return tester
      .widgetList<RawGestureDetector>(find.byType(RawGestureDetector))
      .any((r) => r.gestures.keys.any((t) =>
          t == SingleTouchPanGestureRecognizer ||
          t == SingleTouchHorizontalDragGestureRecognizer ||
          t == SingleTouchVerticalDragGestureRecognizer));
}

void main() {
  // REAL widget-level guard: pumps the actual DirectionalSwipeGestureHandler and
  // asserts it installs NONE of our SingleTouch* drag recognizers in vertical
  // mode (the fix) but DOES in horizontal mode. Reverting the fix makes the
  // vertical case FAIL — this is the regression guard the hand-rolled arena
  // tests below cannot provide.
  group('DirectionalSwipeGestureHandler vertical-mode recognizer guard', () {
    testWidgets('vertical mode installs NO SingleTouch* recognizer (the fix)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(home: _realHandler(Axis.vertical)));
      expect(_hasSingleTouchRecognizer(tester), isFalse,
          reason: 'vertical mode must not register the swipe recognizers — they '
              'steal the single-finger drag from ZoomView and freeze iOS scroll');
    });
    testWidgets('horizontal mode DOES install a SingleTouch* recognizer',
        (tester) async {
      await tester.pumpWidget(MaterialApp(home: _realHandler(Axis.horizontal)));
      expect(_hasSingleTouchRecognizer(tester), isTrue,
          reason: 'horizontal/paged modes keep the swipe recognizers for '
              'chapter-boundary navigation');
    });
  });

  // Run each scenario under both platforms and report the offset delta.
  Future<double> runScenario(
    WidgetTester tester, {
    required TargetPlatform platform,
    required bool forceHoldOnPointerDown,
    required bool useAdvancedGestures,
    bool disableOuterHandler = false,
    double jitterDx = 0,
  }) async {
    debugDefaultTargetPlatformOverride = platform;
    final controller = ScrollController();
    int listenerFires = 0;
    controller.addListener(() => listenerFires++);
    bool scaleStartFired = false;
    bool outerSwipeEnd = false;
    double totalScaleDeltaDy = 0;
    double totalOffsetAppliedInHandler = 0;
    int scaleUpdateCount = 0;
    await tester.pumpWidget(MinimalArena(
      controller: controller,
      forceHoldOnPointerDown: forceHoldOnPointerDown,
      useAdvancedGestures: useAdvancedGestures,
      disableOuterHandler: disableOuterHandler,
      onScaleStartFired: () => scaleStartFired = true,
      onOuterSwipeEnd: () => outerSwipeEnd = true,
      onScaleUpdateDelta: (dy) {
        totalScaleDeltaDy += dy;
        scaleUpdateCount++;
      },
      onOffsetApplied: (d) => totalOffsetAppliedInHandler += d,
    ));
    await tester.pumpAndSettle();

    final r = await _singleFingerVerticalDrag(tester,
        controller: controller, jitterDx: jitterDx);
    debugPrint('[SCENARIO] platform=$platform '
        'forceHold=$forceHoldOnPointerDown advanced=$useAdvancedGestures '
        '=> duringDrag=${r.offsetDuringDrag.toStringAsFixed(1)} '
        'afterSettle=${r.offsetAfterSettle.toStringAsFixed(1)} '
        'physics=${r.physicsType} scaleStartFired=$scaleStartFired '
        'outerSwipeEnd=$outerSwipeEnd scaleUpdates=$scaleUpdateCount '
        'sumScaleDeltaDy=${totalScaleDeltaDy.toStringAsFixed(1)} '
        'sumOffsetAppliedInHandler=${totalOffsetAppliedInHandler.toStringAsFixed(1)} '
        'listenerFires=$listenerFires');
    controller.dispose();
    debugDefaultTargetPlatformOverride = null;
    return r.offsetAfterSettle;
  }

  // IMPORTANT: each platform runs in its OWN testWidgets so it gets a FRESH
  // WidgetTester binding. Running iOS then Android in the SAME test body leaks
  // the first drag's residual pointer/scroll state into the second run and
  // doubles its offset (a harness artifact that initially looked like a real
  // iOS-vs-Android 2x divergence — it is not; it follows RUN ORDER, not
  // platform). Isolating each run kills that leak.

  group('SIMPLE handler (H+V drag), forceHold=true', () {
    testWidgets('iOS', (tester) async {
      final o = await runScenario(tester,
          platform: TargetPlatform.iOS,
          forceHoldOnPointerDown: true,
          useAdvancedGestures: false);
      // Outer VerticalDrag recognizer wins the vertical drag on BOTH platforms;
      // ZoomView scale never starts, position stays held -> zero scroll.
      expect(o, 0.0, reason: 'iOS simple-handler drag should be frozen at 0');
    });
    testWidgets('android', (tester) async {
      final o = await runScenario(tester,
          platform: TargetPlatform.android,
          forceHoldOnPointerDown: true,
          useAdvancedGestures: false);
      expect(o, 0.0, reason: 'android simple-handler drag also frozen at 0');
    });
  });

  group('ADVANCED handler (Pan), forceHold=true', () {
    testWidgets('iOS', (tester) async {
      final o = await runScenario(tester,
          platform: TargetPlatform.iOS,
          forceHoldOnPointerDown: true,
          useAdvancedGestures: true);
      // Pan recognizer does NOT steal a pure-vertical drag pre-slop, so
      // ZoomView scale wins and scroll happens on both platforms.
      expect(o, greaterThan(100),
          reason: 'iOS advanced-handler (Pan) should scroll');
    });
    testWidgets('android', (tester) async {
      final o = await runScenario(tester,
          platform: TargetPlatform.android,
          forceHoldOnPointerDown: true,
          useAdvancedGestures: true);
      expect(o, greaterThan(100),
          reason: 'android advanced-handler (Pan) should scroll');
    });
  });

  group('NO outer handler (pure ZoomView core), forceHold=true', () {
    testWidgets('iOS', (tester) async {
      final o = await runScenario(tester,
          platform: TargetPlatform.iOS,
          forceHoldOnPointerDown: true,
          useAdvancedGestures: true,
          disableOuterHandler: true);
      expect(o, greaterThan(100), reason: 'iOS ZoomView core should scroll');
    });
    testWidgets('android', (tester) async {
      final o = await runScenario(tester,
          platform: TargetPlatform.android,
          forceHoldOnPointerDown: true,
          useAdvancedGestures: true,
          disableOuterHandler: true);
      expect(o, greaterThan(100), reason: 'android ZoomView core should scroll');
    });
  });

  // Realistic drag: a real thumb is never perfectly vertical. With the OUTER
  // Pan recognizer present (advanced handler) competing against ZoomView's
  // scale recognizer, does a jittery vertical drag get STOLEN by Pan on one
  // platform (freezing scroll) but not the other?
  // PINCH-ZOOM PRESERVED. The fix removes the outer SingleTouch* drag
  // recognizers in vertical mode. A two-finger pinch must still reach ZoomView's
  // scale recognizer. Prove it with the outer handler present (default) AND
  // without it (the fix) — both must detect the pinch (scale > 1).
  group('pinch-zoom preserved', () {
    Future<double> runPinch(WidgetTester tester,
        {required bool disableOuterHandler}) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final controller = ScrollController();
      double maxScaleSeen = 1.0;
      await tester.pumpWidget(MinimalArena(
        controller: controller,
        forceHoldOnPointerDown: true,
        useAdvancedGestures: false, // SIMPLE = the default reader config
        disableOuterHandler: disableOuterHandler,
        onScaleFactor: (s) {
          if ((s - 1.0).abs() > (maxScaleSeen - 1.0).abs()) maxScaleSeen = s;
        },
      ));
      await tester.pumpAndSettle();
      await _twoFingerPinch(tester);
      controller.dispose();
      debugDefaultTargetPlatformOverride = null;
      return maxScaleSeen;
    }

    testWidgets('pinch reaches scale recognizer WITH outer handler (default)',
        (tester) async {
      final s = await runPinch(tester, disableOuterHandler: false);
      debugPrint('[PINCH] with outer handler: maxScale=$s');
      expect(s, greaterThan(1.05),
          reason: 'two-finger pinch must reach ZoomView scale recognizer even '
              'with the outer swipe handler present');
    });

    testWidgets('pinch reaches scale recognizer WITHOUT outer handler (the fix)',
        (tester) async {
      final s = await runPinch(tester, disableOuterHandler: true);
      debugPrint('[PINCH] fix (no outer handler): maxScale=$s');
      expect(s, greaterThan(1.05),
          reason:
              'pinch-zoom is preserved after removing the swipe recognizers');
    });
  });

  group('ADVANCED handler (Pan) + outer, JITTERY vertical drag', () {
    testWidgets('iOS (jitter)', (tester) async {
      final o = await runScenario(tester,
          platform: TargetPlatform.iOS,
          forceHoldOnPointerDown: true,
          useAdvancedGestures: true,
          jitterDx: 6);
      debugPrint('[JITTER] iOS advanced+outer jitter=6 => $o');
    });
    testWidgets('android (jitter)', (tester) async {
      final o = await runScenario(tester,
          platform: TargetPlatform.android,
          forceHoldOnPointerDown: true,
          useAdvancedGestures: true,
          jitterDx: 6);
      debugPrint('[JITTER] android advanced+outer jitter=6 => $o');
    });
  });

  // Direct equivalence check: with a fresh binding per platform, the exact same
  // single-finger vertical drag scrolls the list the SAME distance on iOS and
  // Android. If the widget-test arena diverged by platform, these would differ.
  group('iOS == Android equivalence (fresh binding each)', () {
    late double iosAdvanced;
    late double androidAdvanced;

    testWidgets('capture iOS advanced', (tester) async {
      iosAdvanced = await runScenario(tester,
          platform: TargetPlatform.iOS,
          forceHoldOnPointerDown: true,
          useAdvancedGestures: true,
          disableOuterHandler: true);
    });
    testWidgets('capture android advanced', (tester) async {
      androidAdvanced = await runScenario(tester,
          platform: TargetPlatform.android,
          forceHoldOnPointerDown: true,
          useAdvancedGestures: true,
          disableOuterHandler: true);
    });
    test('iOS and Android scroll the same (no 2x divergence, no freeze)', () {
      debugPrint(
          '[EQUIVALENCE] iOS=$iosAdvanced android=$androidAdvanced '
          'diff=${(iosAdvanced - androidAdvanced).abs().toStringAsFixed(1)}');
      // Both scroll a meaningful distance (NOT frozen) and within one touch-
      // slop (~18px) of each other. The tiny gap is iOS consuming slightly more
      // pan-slop at drag START — a one-time start lag, not a scaling factor and
      // not a freeze. The widget-test arena does NOT diverge by platform in a
      // way that would cause "won't scroll on iOS".
      expect(iosAdvanced, greaterThan(100));
      expect(androidAdvanced, greaterThan(100));
      expect((iosAdvanced - androidAdvanced).abs(), lessThan(25.0),
          reason:
              'clean per-platform runs scroll within one touch-slop; no 2x '
              'divergence, no iOS freeze');
    });
  });
}
