// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.overlay;

import 'dart:async';
import 'dart:html';

import 'package:polymer/polymer.dart';

import '../common/spark_widget.dart';

// Ported from Polymer Javascript to Dart code.
@CustomTag("spark-overlay")
class SparkOverlay extends SparkWidget {
  // Track overlays for z-index and focus managemant.
  static List overlays = [];

  static void trackOverlays(inOverlay) {
    if (inOverlay.opened) {
      var z0 = currentOverlayZ();
      overlays.add(inOverlay);
      var z1 = currentOverlayZ();
      if (z0 != null && z1 != null && z1 <= z0) {
        applyOverlayZ(inOverlay, z0);
      }
    } else {
      var i = overlays.indexOf(inOverlay);
      if (i >= 0) {
        overlays.removeAt(i);
        setZ(inOverlay, null);
      }
    }
  }

  static void applyOverlayZ(inOverlay, inAboveZ) {
    setZ(inOverlay, inAboveZ + 2);
  }

  static void setZ(inNode, inZ) {
    inNode.style.zIndex = "$inZ";
  }

  static currentOverlay() {
    return overlays.isNotEmpty ? overlays.last : null;
  }

  static int DEFAULT_Z = 1000;

  static currentOverlayZ() {
    var z = DEFAULT_Z;
    var current = currentOverlay();
    if (current != null) {
      var z1 = current.getComputedStyle().zIndex;
      z = int.parse(z1, onError: (source) { });
    }
    return z;
  }

  static void focusOverlay() {
    var current = currentOverlay();
    if (current != null) {
      current.focus();
    }
  }

  // Function closures aren't canonicalized: need to have one pointer for the
  // listener's handler that is added/removed.
  EventListener _captureHandler;
  EventListener _resizeHandler;

  SparkOverlay.created(): super.created() {
    _captureHandler = captureHandler;
    _resizeHandler = resizeHandler;
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
  @published String animation = '';

  static final List<String> SUPPORTED_ANIMATIONS = [
    'fade', 'shake', 'scale-slideup'
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

  Timer autoCloseTask = null;

  @override
  void enteredView() {
    super.enteredView();

    assert(SUPPORTED_ANIMATIONS.contains(animation));

    style.visibility = "visible";

    enableKeyboardEvents();

    addEventListener('webkitAnimationStart', openedAnimationStart);
    addEventListener('animationStart', openedAnimationStart);
    addEventListener('webkitAnimationEnd', openedAnimationEnd);
    addEventListener('animationEnd', openedAnimationEnd);
    addEventListener('webkitTransitionEnd', openedTransitionEnd);
    addEventListener('transitionEnd', openedTransitionEnd);
    addEventListener('click', tapHandler);
    addEventListener('keydown', keyDownHandler);
  }

  /// Toggle the opened state of the overlay.
  void toggle() {
    opened = !opened;
  }

  void openedChanged() {
    renderOpened();
    trackOverlays(this);

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
      window.addEventListener('resize', _resizeHandler);
    } else {
      window.removeEventListener('resize', _resizeHandler);
    }
  }

  void _enableCaptureHandler(bool enable, Iterable<String> eventTypes) {
    final Function addRemoveFunc =
        enable ? document.addEventListener : document.removeEventListener;
    eventTypes.forEach((et) => addRemoveFunc(et, _captureHandler, true));
  }

  void applyFocus() {
    if (opened) {
      focus();
    } else {
      // Focus the next overlay in the stack.
      focusOverlay();
    }
  }

  void renderOpened() {
    classes.remove('closing');
    classes.add('revealed');
    // continue styling after delay so display state can change without
    // aborting transitions
    Timer.run(() { continueRenderOpened(); });
//    asyncMethod('continueRenderOpened');
  }

  void continueRenderOpened() {
    classes.toggle('opened', opened);
    classes.toggle('closing', !opened);
//    this.animating = this.asyncMethod('completeOpening', null, this.timeout);
  }

  void completeOpening() {
//    clearTimeout(this.animating);
    classes.remove('closing');
    classes.toggle('revealed', opened);
    applyFocus();
  }

  void openedAnimationEnd(AnimationEvent e) {
    if (!opened) {
      classes.remove('animation-in-progress');
    }
    // same steps as when a transition ends
    openedTransitionEnd(e);
  }

  void openedTransitionEnd(Event e) {
    // TODO(sorvell): Necessary due to
    // https://bugs.webkit.org/show_bug.cgi?id=107892
    // Remove when that bug is addressed.
    if (e.target == this) {
      completeOpening();
      e.stopImmediatePropagation();
      e.preventDefault();
    }
  }

  void openedAnimationStart(AnimationEvent e) {
    classes.add('animation-in-progress');
    e.stopImmediatePropagation();
    e.preventDefault();
  }

  void tapHandler(MouseEvent e) {
    Element target = e.target;
    if (target != null && target.attributes.containsKey('overlay-toggle')) {
      toggle();
    } else if (autoCloseTask != null) {
      autoCloseTask.cancel();
      autoCloseTask = null;
    }
  }

  void captureHandler(Event e) {
    final bool inOverlay =
        (e is MouseEvent && isPointInOverlay(e.client)) ||
        this == e.target ||
        this.contains(e.target) ||
        shadowRoot.contains(e.target);

    if (!inOverlay) {
      if (modal) {
        e..stopPropagation()..preventDefault();
      }
      if (autoClose) {
        autoCloseTask = new Timer(Duration.ZERO, () { opened = false; });
      }
    }
  }

  bool isPointInOverlay(Point xyGlobal) {
    return super.getBoundingClientRect().containsPoint(xyGlobal);
  }

  void keyDownHandler(KeyboardEvent e) {
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
