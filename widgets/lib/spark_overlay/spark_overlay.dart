// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.overlay;

import 'dart:async';
import 'dart:html';

import 'package:polymer/polymer.dart';

import '../common/spark_widget.dart';

// TODO(ussuri): add more comments.

class _SparkOverlayManager {
  // Track overlays for z-index and focus managemant.
  // TODO(ussuri): The z-index management with a fixed base z-index is shaky at
  // best. SparkOverlay doesn't know in what z-index environment its instances
  // will live, so assumption that 1000 is always a good value is invalid.
  // Consider:
  // 1) Stacking contexts (https://developer.mozilla.org/en-US/docs/Web/Guide/CSS/Understanding_z_index/The_stacking_context).
  // 2) Some way to set the base z-index in the client.
  // 3) Set the same z-index for all spark-overlays in the client, then bump
  //    the current overlay's z-index if any other are currently opened.
  static final List<SparkOverlay> overlays = [];

  static void trackOverlays(SparkOverlay inOverlay) {
    if (inOverlay.opened) {
      final int z0 = _currentOverlayZ();
      overlays.add(inOverlay);
      final int z1 = _currentOverlayZ();
      if (z0 != null && z1 != null && z1 <= z0) {
        _applyOverlayZ(inOverlay, z0);
      }
    } else {
      final int i = overlays.indexOf(inOverlay);
      if (i >= 0) {
        overlays.removeAt(i);
        _setZ(inOverlay, null);
      }
    }
  }

  static void _applyOverlayZ(SparkOverlay inOverlay, int inAboveZ) {
    _setZ(inOverlay, inAboveZ + 2);
  }

  static void _setZ(Element inNode, int inZ) {
    inNode.style.zIndex = "$inZ";
  }

  static _currentOverlay() {
    return overlays.isNotEmpty ? overlays.last : null;
  }

  // TODO(ussuri): This widget doesn't know in which z-index environment it's
  // going to live. Choosing an arbitrary starting z-index here is wrong. Redo.
  static const int _DEFAULT_Z = 1000;

  static _currentOverlayZ() {
    int z = _DEFAULT_Z;
    final SparkOverlay current = _currentOverlay();
    if (current != null) {
      final z1 = current.getComputedStyle().zIndex;
      z = int.parse(z1, onError: (source) { });
    }
    return z;
  }

  static void focusOverlay() {
    final SparkOverlay current = _currentOverlay();
    if (current != null) {
      current.focus();
    }
  }
}

@CustomTag("spark-overlay")
class SparkOverlay extends SparkWidget {
  bool _opened = false;

  /**
   * Set opened to true to show an overlay and to false to hide it.
   * A spark-overlay may be made intially opened by setting its opened
   * attribute.
   */
  @published bool get opened => _opened;

  @published set opened(bool val) {
    if (_opened != val) {
      _opened = val;
      // TODO(ussuri): Getter/setter were needed to fix the Menu and Modal not
      // working in the deployed code. With a simple `@published bool opened`,
      // writes to it via data binding or direct assignment elsewhere here
      // were not detected (didn't invoke [openedChanged]).
      openedChanged();
    }
  }

  /**
   * Adds an arrow on a side of the overlay at a specified location.
   */
  @published String arrow = 'none';

  static final List<String> _SUPPORTED_ARROWS = [
    'none', 'top-center', 'top-left', 'top-right'
  ];

  /**
   * Prevents other elements in the document from receiving [_captureEventTypes]
   * events. This essentially disables the rest of the UI while the overlay
   * is open.
   */
  @published bool modal = false;

  /**
   * Close the overlay automatically if the user taps outside it or presses
   * the escape key.
   */
  @published bool autoClose = false;

  /**
   * The kind of animation that the overlay should perform on open/close.
   */
  @PublishedProperty(reflect: true) String animation = 'none';

  static final List<String> _SUPPORTED_ANIMATIONS = [
    'none', 'fade', 'shake', 'scale-slideup'
  ];

  Timer _autoCloseTask = null;

  List<StreamSubscription> _eventSubs = [];

  SparkOverlay.created(): super.created();

  @override
  void attached() {
    super.attached();

    assert(_SUPPORTED_ARROWS.contains(arrow));
    assert(_SUPPORTED_ANIMATIONS.contains(animation));

    style.visibility = "visible";

    // TODO(ussuri): This has been causing problems with ghost overlays
    // lingering after closing and reacting to mouse clicks etc.
    // E.g. try to open and close the menu and click in the area where it was.
    // enableKeyboardEvents();

    window.onAnimationStart.listen(_openedAnimationStart);
    window.onAnimationEnd.listen(_openedAnimationEnd);
    onTransitionEnd.listen(_openedTransitionEnd);
    onClick.listen(_tapHandler);
    onKeyDown.listen(_keyDownHandler);
  }

  void show() {
    if (!opened) opened = true;
  }

  void hide() {
    if (opened) opened = false;
  }

  /**
   * Toggle the opened state of the overlay.
   */
  void toggle() {
    opened = !opened;
  }

  void openedChanged() {
    _renderOpened();

    _SparkOverlayManager.trackOverlays(this);

    if (opened) {
      _eventSubs.addAll(
          SparkWidget.addEventHandlers([window.onResize], resizeHandler));

      /**
       * For modal and auto-closing overlays, intercept and block some events
       * at the [document] level during the event capture phase.
       */
      if (autoClose || modal) {
        final eventStreams = new Set<Stream<Event>>();
        if (modal) {
          eventStreams.addAll([
              document.body.onMouseDown,
              document.body.onMouseUp,
              document.body.onClick,
              document.body.onDoubleClick,
              document.body.onMouseWheel,
              document.body.onContextMenu,
              document.body.onFocus,
              document.body.onBlur,
          ]);
        }
        if (autoClose) {
          eventStreams.addAll([
              document.body.onMouseDown,
              document.body.onMouseWheel,
              document.body.onContextMenu,
          ]);
        }
        _eventSubs.addAll(
            SparkWidget.addEventHandlers(
                eventStreams, _captureHandler, capture: true));
      }
    } else {
      SparkWidget.removeEventHandlers(_eventSubs);
    }

    fire('transition-start', detail: {'opening': opened});
  }

  void _applyFocus() {
    if (opened) {
      focus();
    } else {
      // Focus the next overlay in the stack.
      _SparkOverlayManager.focusOverlay();
    }
  }

  void _renderOpened() {
    classes.remove('closing');
    classes.add('revealed');
    // Continue styling after delay so display state can change without
    // aborting transitions.
    Timer.run(() { _continueRenderOpened(); });
  }

  void _continueRenderOpened() {
    classes.toggle('opened', opened);
    classes.toggle('closing', !opened);
  }

  void _completeOpening() {
    classes.remove('closing');
    classes.toggle('revealed', opened);
    _applyFocus();

    fire('transition-end', detail: {'opened': opened});
  }

  void _openedAnimationEnd(AnimationEvent e) {
    if (!opened) {
      classes.remove('animation-in-progress');
    }
    // Same steps as when a transition ends.
    _openedTransitionEnd(e);
  }

  void _openedTransitionEnd(Event e) {
    // TODO(sorvell): Necessary due to
    // https://bugs.webkit.org/show_bug.cgi?id=107892
    // Remove when that bug is addressed.
    if (e.target == this) {
      _completeOpening();
      e..stopImmediatePropagation()..preventDefault();
    }
  }

  void _openedAnimationStart(AnimationEvent e) {
    classes.add('animation-in-progress');
    e..stopImmediatePropagation()..preventDefault();
  }

  void _tapHandler(MouseEvent e) {
    Element target = e.target;
    if (target != null && target.attributes.containsKey('overlayToggle')) {
      hide();
    } else if (_autoCloseTask != null) {
      _autoCloseTask.cancel();
      _autoCloseTask = null;
    }
  }

  /**
   * If a mouse or keyboard event is outside the overlay, handle auto-closing
   * and modality, as set.
   */
  void _captureHandler(Event e) {
    final bool inOverlay = isEventInWidget(e);

    if (!inOverlay) {
      if (modal) {
        e..stopPropagation()..preventDefault();
      }
      if (autoClose) {
        _autoCloseTask = new Timer(Duration.ZERO, () { opened = false; });
      }
    }
  }

  void _keyDownHandler(KeyboardEvent e) {
    if (e.keyCode == KeyCode.ESC) {
      opened = false;
    }
  }

  /**
   * Extensions of spark-overlay should implement the resizeHandler
   * method to adjust the size and position of the overlay when the
   * browser window resizes.
   */
  void resizeHandler(e) {
  }
}
