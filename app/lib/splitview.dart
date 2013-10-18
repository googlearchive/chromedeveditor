// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.splitview;

import 'dart:html';
import 'html_utils.dart';

/**
 * This class encapsulates a splitview. It's a view with two panels and a
 * separator that can be moved.
 */

class SplitView {
  // When the separator is being moved.
  bool _resizeStarted = false;
  int _resizeStartX;
  int _initialPositionX;
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
    _leftView = splitView.query('.left');
    _rightView = splitView.query('.right');

    // Is the separator horizontal or vertical?
    // It will depend on the initial layout of the left/right views.
    _horizontal =
        (getAbsolutePosition(_leftView).x ==getAbsolutePosition(_rightView).x);

    // Minimum size of the views.
    String minSizeString = _leftView.attributes['min-size'];
    if (minSizeString != null) {
      _leftMinSize = int.parse(minSizeString);
    }
    minSizeString = _rightView.attributes['min-size'];
    if (minSizeString != null) {
      _rightMinSize = int.parse(minSizeString);
    }

    // Separator and drag zone of the separator.
    const int splitterMargin = 3;
    _splitter = new DivElement();
    _splitter.classes.add('splitter');
    _splitter.style
      ..height = '100%'
      ..width = '1px'
      ..position = 'absolute';
    _splitView.children.add(_splitter);
    _splitterHandle = new DivElement();
    _splitterHandle.classes.add('splitter-handle');
    _splitterHandle.style
      ..position = 'relative'
      ..height = '100%'
      ..cursor = 'ew-resize'
      ..zIndex = '100';
    _splitter.children.add(_splitterHandle);

    if (_isVertical()) {
      _splitterHandle.style
        ..left = (-splitterMargin).toString() + 'px'
        ..width = (splitterMargin * 2).toString() + 'px';
    } else {
      _splitterHandle.style
        ..left = (-splitterMargin).toString() + 'px'
        ..width = (splitterMargin * 2).toString() + 'px';
    }

    // Set initial position of the separator.
    _setSplitterPosition(_leftView.clientWidth);

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

  void _resizeDownHandler(MouseEvent event) {
    if (_isHorizontal()) {
      // splitter is horizontal.
      if (isMouseLocationInElement(event, _splitterHandle, 0, 0)) {
        _resizeStarted = true;
      }
    } else {
      // splitter is vertical.
      if (isMouseLocationInElement(event, _splitterHandle, 0, 0)) {
        _resizeStarted = true;
      }
    }
    if (_resizeStarted) {
      _resizeStartX = event.screenX;
      _initialPositionX = _splitter.offsetLeft;
    }
  }

  void _resizeMoveHandler(MouseEvent event) {
    if (_resizeStarted) {
      int value = _initialPositionX + event.screenX - _resizeStartX;
      if (value > _splitView.clientWidth - _rightMinSize) {
        value = _splitView.clientWidth - _rightMinSize;
      }
      if (value < _leftMinSize) {
        value = _leftMinSize;
      }
      _setSplitterPosition(value);
    }
  }

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
    _leftView.style.width = position.toString() + 'px';
    _splitter.style.left = position.toString() + 'px';
    _rightView.style
      ..left = (position + 1).toString() + 'px'
      ..width = 'calc(100% - ' + (position + 1).toString() + 'px)';
  }
}
