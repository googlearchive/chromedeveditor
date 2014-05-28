// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.overlay;

import 'dart:async';
import 'dart:html';

import 'package:polymer/polymer.dart';

import '../common/spark_widget.dart';

@CustomTag("spark-overlay")
class SparkOverlay extends SparkWidget {
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

  static void _trackOverlays(SparkOverlay inOverlay) {
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

  static void _focusOverlay() {
    final SparkOverlay current = _currentOverlay();
    if (current != null) {
      current.focus();
    }
  }

  // Function closures aren't canonicalized: need to have one pointer for the
  // listener's handler that is added/removed.
  EventListener _captureHandlerInst;
  EventListener _resizeHandlerInst;

  SparkOverlay.created(): super.created() {
    _captureHandlerInst = _captureHandler;
    _resizeHandlerInst = _resizeHandler;
  }

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
  @published String animation = 'none';

  static final List<String> _SUPPORTED_ANIMATIONS = [
    'none', 'fade', 'shake', 'scale-slideup'
  ];

  /**
   * Events to capture on the [document] level in the capturing event
   * propagation phase and either block them (with [modal]) or auto-close the
   * overlay (with [autoClose]).
   */
  // TODO(ussuri): This list should be amended with 'tap*' events when
  // PointerEvents are supported.
  // NOTE(ussuri): Possible other candidates to consider (note that some
  // may break e.g. manually applied hovering within the overlay itself):
  // 'mouseenter',
  // 'mouseleave',
  // 'mouseover',
  // 'mouseout',
  // 'focusin',
  // 'focusout',
  // 'scroll',
  // 'keydown',
  // 'keypress',
  // 'keyup'
  static final List<String> _modalEventTypes = [
      'mousedown',
      'mouseup',
      'click',
      'wheel',
      'dblclick',
      'contextmenu',
      'focus',
      'blur',
  ];
  static final List<String> _autoCloseEventTypes = [
      'mousedown',
      'wheel',
      'contextmenu',
  ];

  Timer _autoCloseTask = null;

  @override
  void enteredView() {
    super.enteredView();

    assert(_SUPPORTED_ARROWS.contains(arrow));
    assert(_SUPPORTED_ANIMATIONS.contains(animation));

    style.visibility = "visible";

    // TODO(ussuri): This has been causing problems with ghost overlays
    // lingering after closing and reacting to mouse clicks etc.
    // E.g. try to open and close the menu and click in the area where it was.
    // enableKeyboardEvents();

    addEventListener('webkitAnimationStart', _openedAnimationStart);
    addEventListener('animationStart', _openedAnimationStart);
    addEventListener('webkitAnimationEnd', _openedAnimationEnd);
    addEventListener('animationEnd', _openedAnimationEnd);
    addEventListener('webkitTransitionEnd', _openedTransitionEnd);
    addEventListener('transitionEnd', _openedTransitionEnd);
    addEventListener('click', _tapHandler);
    addEventListener('keydown', _keyDownHandler);
  }

  /// Toggle the opened state of the overlay.
  void toggle() {
    opened = !opened;
  }

  void openedChanged() {
    _renderOpened();
    _trackOverlays(this);

    _enableResizeHandler(opened);

    if (autoClose || modal) {
      var eventTypes = new Set<String>();
      if (modal) eventTypes.addAll(_modalEventTypes);
      if (autoClose) eventTypes.addAll(_autoCloseEventTypes);
      _enableCaptureHandler(opened, eventTypes);
    }

    asyncFire('opened', detail: opened);
  }

  void _enableResizeHandler(inEnable) {
    if (inEnable) {
      window.addEventListener('resize', _resizeHandlerInst);
    } else {
      window.removeEventListener('resize', _resizeHandlerInst);
    }
  }

  void _enableCaptureHandler(bool enable, Iterable<String> eventTypes) {
    final Function addRemoveFunc =
        enable ? document.addEventListener : document.removeEventListener;
    eventTypes.forEach((et) => addRemoveFunc(et, _captureHandlerInst, true));
  }

  void _applyFocus() {
    if (opened) {
      focus();
    } else {
      // Focus the next overlay in the stack.
      _focusOverlay();
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
      e.stopImmediatePropagation();
      e.preventDefault();
    }
  }

  void _openedAnimationStart(AnimationEvent e) {
    classes.add('animation-in-progress');
    e.stopImmediatePropagation();
    e.preventDefault();
  }

  void _tapHandler(MouseEvent e) {
    Element target = e.target;
    if (target != null && target.attributes.containsKey('overlay-toggle')) {
      toggle();
    } else if (_autoCloseTask != null) {
      _autoCloseTask.cancel();
      _autoCloseTask = null;
    }
  }

  void _captureHandler(Event e) {
    final bool inOverlay =
        (e is MouseEvent && _isPointInOverlay(e.client)) ||
        this == e.target ||
        this.contains(e.target) ||
        shadowRoot.contains(e.target);

    if (!inOverlay) {
      if (modal) {
        e..stopPropagation()..preventDefault();
      }
      if (autoClose) {
        _autoCloseTask = new Timer(Duration.ZERO, () { opened = false; });
      }
    }
  }

  bool _isPointInOverlay(Point xyGlobal) {
    return super.getBoundingClientRect().containsPoint(xyGlobal);
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
  void _resizeHandler(e) {
  }
}
