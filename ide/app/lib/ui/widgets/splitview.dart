// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.ui.widgets.splitview;

import 'dart:html';
import 'dart:async';

/**
 * This class encapsulates a splitview. It's a view with two panels and a
 * separator that can be moved.
 */
class SplitView {
  /// The default initial position of the splitter.
  static const int DEFAULT_INITIAL_POSITION = 300;

  /// Whether the separator is horizontal or vertical.
  bool _horizontal;

  /// Minimum size of the first view.
  int _minSizeA = 0;

  /// Minimum size of the second view.
  int _minSizeB = 0;

  /// Current position of the splitter.
  int _position;

  /// When the separator is being moved.
  int _initialPosition;

  /// The element containing two sub views.
  Element _splitView;

  /// The separator of between the views.
  Element _splitter;

  /// The element of the area that can be dragged with the mouse to move the
  /// separator. It is invisible and a little bit wider than [_splitter].
  Element _splitterHandle;

  /// The first view.
  Element _viewA;

  /// The second view.
  Element _viewB;

  /// Stream controller for resize event.
  StreamController<int> _onResizedContoller =
      new StreamController<int>.broadcast();

  /// The subscription of the mouse move event when dragging.
  StreamSubscription<MouseEvent> _onMouseMoveSubscription;

  /// The subscription of the mouse up event when dragging.
  StreamSubscription<MouseEvent> _onMouseUpSubscription;

  /**
   * Constructor the the SplitView. The element must contain exactly two
   * elements.
   * The separator element will be injected.
   */
  SplitView(Element this._splitView, {
      bool horizontal: false,
      int position: DEFAULT_INITIAL_POSITION}) {

    _viewA = _splitView.children[0];
    _viewB = _splitView.children[1];

    _splitterHandle = new DivElement();
    _splitterHandle.classes.add('splitter-handle');

    _splitter = new DivElement()
        ..classes.add('splitter')
        ..children.add(_splitterHandle);

    _splitView.children.insert(1, _splitter);

    // Minimum size of the views.
    String minSizeString = _viewA.attributes['min-size'];
    if (minSizeString != null) {
      minSizeA = int.parse(minSizeString);
    }

    minSizeString = _viewB.attributes['min-size'];
    if (minSizeString != null) {
      minSizeB = int.parse(minSizeString);
    }

    this.horizontal = horizontal;
    this.position = position;

    document.onMouseDown.listen(_resizeDownHandler);
  }

  /// OnResized event.
  Stream<int> get onResized => _onResizedContoller.stream;

  /// Gets/sets whether the splitview splits horizontally.
  bool get horizontal => _horizontal;
  void set horizontal(bool horizontal) {
    if (_horizontal != horizontal) {
      _horizontal = horizontal;
      _splitView.classes.toggle('splitview-horizontal', horizontal);
      _splitView.classes.toggle('splitview-vertical', !horizontal);
      // Refresh the position.
      position = position;
    }
  }

  /// Gets/sets whether the splitview splits vertically.
  bool get vertical => !horizontal;
  set vertical(bool vertical) {
    horizontal = !vertical;
  }

  /// Gets/sets minimum sized of the first sub-view.
  int get minSizeA => _minSizeA;
  void set minSizeA(int minSizeA) {
    if (horizontal) {
      _viewA.style.minHeight = '${minSizeA}px';
    } else {
      _viewA.style.minWidth = '${minSizeA}px';
    }
  }

  /// Gets/sets minimum sized of the second sub-view.
  int get minSizeB => _minSizeB;
  void set minSizeB(int minSizeB) {
    if (horizontal) {
      _viewB.style.minHeight = '${minSizeB}px';
    } else {
      _viewB.style.minWidth = '${minSizeB}px';
    }
  }

  /// Gets/sets the current position of the splitter.
  int get position => _position;
  void set position(int position) {
    _position = position;
    if (horizontal) {
      _viewA.style.height = '${position}px';
    } else {
      _viewA.style.width = '${position}px';
    }
    // File on resize event.
    _onResizedContoller.add(position);
  }

  /// Get effective coordinate of a mouse event according to the split
  /// direction.
  int _getOffsetFromEvent(MouseEvent event) =>
      horizontal ? event.screen.y : event.screen.x;

  /// Event handler for mouse button down.
  void _resizeDownHandler(MouseEvent event) {
    if (event.button == 0 && event.target == _splitterHandle) {
      _initialPosition = position - _getOffsetFromEvent(event);

      _onMouseMoveSubscription =
          document.onMouseMove.listen(_resizeMoveHandler);
      _onMouseUpSubscription = document.onMouseUp.listen(_resizeUpHandler);

      event.stopPropagation();
      event.preventDefault();
    }
  }

  /// Event handler for mouse move.
  void _resizeMoveHandler(MouseEvent event) {
    position = _initialPosition + _getOffsetFromEvent(event);
    event.stopPropagation();
    event.preventDefault();
  }

  /// Event handler for mouse button up.
  void _resizeUpHandler(MouseEvent event) {
    _onMouseMoveSubscription.cancel();
    _onMouseMoveSubscription = null;
    _onMouseUpSubscription.cancel();
    _onMouseUpSubscription = null;
  }
}
