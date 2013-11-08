// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.ui.widgets.splitview;

import 'dart:html';
import '../utils/html_utils.dart';

/**
 * This class encapsulates a splitview. It's a view with two panels and a
 * separator that can be moved.
 */

class SplitView {
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
  // The left view.
  Element _leftView;
  // The right view.
  Element _rightView;
  // Whether the separator is horizontal (or vertical).
  bool _horizontal;
  // Minimum size of the left view.
  int _leftMinSize = 0;
  // Minimum size of the right view.
  int _rightMinSize = 0;

  /**
   * Constructor the the SplitView. The element must contain a left view with
   * class .left and a right view with class .right.
   * The separator element will be created.
   */
  SplitView(Element splitView) {
    _splitView = splitView;
    _leftView = splitView.querySelector('.left');
    _rightView = splitView.querySelector('.right');

    _splitter = new DivElement();
    _splitter.classes.add('.splitter');

    _splitterHandle = new DivElement();
    _splitterHandle.classes.add('.splitter-handle');
    _splitter.children.add(_splitterHandle);

    _splitView.children.insert(1, _splitter);

    // Is the separator horizontal or vertical?
    // It will depend on the initial layout of the left/right views.
    _horizontal =
        (getAbsolutePosition(_leftView).x == getAbsolutePosition(_rightView).x);

    // Minimum size of the views.
    String minSizeString = _leftView.attributes['min-size'];
    if (minSizeString != null) {
      _leftMinSize = int.parse(minSizeString);
    }
    minSizeString = _rightView.attributes['min-size'];
    if (minSizeString != null) {
      _rightMinSize = int.parse(minSizeString);
    }

    document
      ..onMouseDown.listen(_resizeDownHandler)
      ..onMouseMove.listen(_resizeMoveHandler)
      ..onMouseUp.listen(_resizeUpHandler);
  }

  bool _isHorizontal() {
    return _horizontal;
  }

  bool _isVertical() {
    return !_isHorizontal();
  }

  /**
   * Event handler for mouse button down.
   */
  void _resizeDownHandler(MouseEvent event) {
    // splitter is vertical.
    if (event.button == 0 && event.target == _splitterHandle) {
      _resizeStarted = true;
      if (_isVertical()) {
        _resizeStart = event.screen.x;
        _initialPosition = _leftView.offsetWidth;
      } else {
        _resizeStart = event.screen.y;
        _initialPosition = _leftView.offsetHeight;
      }
    }
  }

  /**
   * Event handler for mouse move.
   */
  void _resizeMoveHandler(MouseEvent event) {
    if (_resizeStarted) {
      int value = _initialPosition + event.screen.x - _resizeStart;

      if (value > _splitView.clientWidth - _rightMinSize) {
        value = _splitView.clientWidth - _rightMinSize;
      }
      if (value < _leftMinSize) {
        value = _leftMinSize;
      }
      _setSplitterPosition(value);
    }
  }

  /**
   * Event handler for mouse button up.
   */
  void _resizeUpHandler(MouseEvent event) {
    if (_resizeStarted) {
      _resizeStarted = false;
    }
  }

  /*
   * Set the new location of the separator. It will also change the size of
   * the left view and the right view, depending on the location of the
   * separator.
   */
  void _setSplitterPosition(int position) {
    if (_isVertical()) {
      _leftView.style.width = position.toString() + 'px';
    } else {
      _leftView.style.height = position.toString() + 'px';
    }
    _rightView.dispatchEvent(new Event('scroll'));
    _rightView.style.width = 'auto';
    _rightView.style.height = 'auto';
  }
}
