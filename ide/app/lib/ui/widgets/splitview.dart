// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.ui.widgets.splitview;

import 'dart:html';
import 'dart:async';
import '../utils/html_utils.dart';

/**
 * This class encapsulates a splitview. It's a view with two panels and a
 * separator that can be moved.
 */

class SplitView {
  static const int DEFAULT_INITIAL_POSITION = 300;
  // When the separator is being moved.
  bool _resizeStarted = false;
  int _resizeStart;
  int _initialPosition;
  // The element containing left and right view.
  Element _splitView;
  // The separator of between the views.
  Element _splitter;
  // The element of the area that can be dragged with the mouse to move the
  // separator.
  Element _splitterHandle;
  // The first view.
  Element _viewA;
  // The second view.
  Element _viewB;
  // Whether the separator is horizontal (or vertical).
  bool _horizontal;
  // Minimum size of the left view.
  int _minSizeA = 0;
  // Minimum size of the right view.
  int _minSizeB = 0;
  // Current position of the splitter.
  int _position;
  // Stream controller for resize event.
  StreamController<int> _onResizedContoller =
      new StreamController<int>.broadcast();

  /**
   * Constructor the the SplitView. The element must contain a left view with
   * class .left and a right view with class .right.
   * The separator element will be created.
   */
  SplitView(Element this._splitView, {
      bool horizontal: false,
      int position: DEFAULT_INITIAL_POSITION}) {
    this.horizontal = horizontal;
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

    this.position = position;

    document
      ..onMouseDown.listen(_resizeDownHandler)
      ..onMouseMove.listen(_resizeMoveHandler)
      ..onMouseUp.listen(_resizeUpHandler);
  }

  /**
   * OnResized event.
   */
  Stream<int> get onResized => _onResizedContoller.stream;

  /**
   * Gets/sets whether the splitview splits horizontally.
   */
  bool get horizontal => _horizontal;
  void set horizontal(bool horizontal) {
    if (_horizontal != horizontal) {
      _horizontal = horizontal;
      _splitView.classes.toggle('splitview-horizontal', horizontal);
      _splitView.classes.toggle('splitview-vertical', !horizontal);
    }
  }

  /**
   * Gets/sets whether the splitview splits vertically.
   */
  bool get vertical => !horizontal;
  void set vertical(bool vertical) {
    horizontal = !vertical;
    position = position;
  }

  /**
   * Gets/sets minimum sized of the first sub-view.
   */
  int get minSizeA => _minSizeA;
  void set minSizeA(int minSizeA) {
    if (horizontal) {
      _viewA.style.minHeight = "${minSizeA}px";
    } else {
      _viewA.style.minWidth = "${minSizeA}px";
    }
  }

  /**
   * Gets/sets minimum sized of the second sub-view.
   */
  int get minSizeB => _minSizeB;
  void set minSizeB(int minSizeB) {
    if (horizontal) {
      _viewB.style.minHeight = "${minSizeB}px";
    } else {
      _viewB.style.minWidth = "${minSizeB}px";
    }
  }

  /**
   * Gets/sets the current position of the splitter.
   */
  int get position => _position;
  void set position(int position) {
    _position = position;
    if (horizontal) {
      _viewA.style.height = position.toString() + 'px';
    } else {
      _viewA.style.width = position.toString() + 'px';
    }
    // File on resize event.
    _onResizedContoller.add(position);
  }

  /**
   * Event handler for mouse button down.
   */
  void _resizeDownHandler(MouseEvent event) {
    // splitter is vertical.
    if (event.button == 0 && event.target == _splitterHandle) {
      _resizeStarted = true;
      if (vertical) {
        _resizeStart = event.screen.x;
        _initialPosition = _viewA.offsetWidth;
      } else {
        _resizeStart = event.screen.y;
        _initialPosition = _viewA.offsetHeight;
      }
    }
  }

  /**
   * Event handler for mouse move.
   */
  void _resizeMoveHandler(MouseEvent event) {
    if (_resizeStarted) {
      int value = _initialPosition - _resizeStart;
      if (horizontal) {
        value += event.screen.y;
      } else {
        value += event.screen.x;
      }
      position = value;
    }
  }

  /**
   * Event handler for mouse button up.
   */
  void _resizeUpHandler(MouseEvent event) {
    _resizeStarted = false;
  }
}
