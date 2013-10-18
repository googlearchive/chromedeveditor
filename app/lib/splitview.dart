// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.splitview;

import 'dart:html';

// splitview
// +- .left
// +- .splitter
// +- .right

class SplitView {
  SplitView(Element splitView) {
    _resizeStarted = false;
    
    _splitView = splitView;
    _leftView = splitView.query('left');
    _rightView = splitView.query('right');

    _horizontal = (getAbsolutePosition(_leftView).x == getAbsolutePosition(_rightView).x);

    _leftMinSize = int.parse(_leftView.getAttribute('left'));
    _rightMinSize = int.parse(_rightView.getAttribute('right'));

    int splitterMargin = 3;
    _splitter = new DivElement();
    _splitter.classes.add('splitter');
    _splitter.style.height = '100%';
    _splitter.style.width = '1px';
    _splitView.children.add(_splitter);
    _splitterHandle = new DivElement();
    _splitterHandle.classes.add('splitter-handle');
    _splitter.children.add(splitterHandle);

    if (_isVertical()) {
      _splitterHandle.style.left = (-splitterMargin).toString() + 'px';
      _splitterHandle.style.width = (splitterMargin * 2).toString() + 'px';
    } else {
      _splitterHandle.style.left = (-splitterMargin).toString() + 'px';
      _splitterHandle.style.width = (splitterMargin * 2).toString() + 'px';
    }

    document.onMouseDown.listen(_resizeDownHandler);
    document.onMouseMove.listen(_resizeMoveHandler);
    document.onMouseUp.listen(_resizeUpHandler);
  }

  bool _isHorizontal() {
    return _splitter.offsetWidth > _splitter.offsetHeight;
  }

  bool _isVertical() {
    return !_isHorizontal();
  }

  void _resizeDownHandler(MouseEvent event) {
    Element splitter = query('#splitter');
    if (_isHorizontal()) {
      // splitter is horizontal.
      if (isMouseLocationInElement(event, query('#splitter .splitter-handle'), 0, 0)) {
        _resizeStarted = true;
      }
    } else {
      // splitter is vertical.
      if (isMouseLocationInElement(event, query('#splitter .splitter-handle'), 0, 0)) {
        _resizeStarted = true;
      }
    }
    if (_resizeStarted) {
      _resizeStartX = event.screenX;
      _initialPositionX = splitter.offsetLeft;
    }
  }

  void _resizeMoveHandler(MouseEvent event) {
    if (_resizeStarted) {
      int value = _initialPositionX + event.screenX - _resizeStartX;
      if (value > query('#splitview').clientWidth - _rightMinSize) {
        value = query('#splitview').clientWidth - _rightMinSize;
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

  void _setSplitterPosition(int position) {
    _leftView.style.width = position.toString() + 'px';
    _splitter.style.left = position.toString() + 'px';
    _rightView.style.left = (position + 1).toString() + 'px';
    _rightView.style.width = 'calc(100% - ' + (position + 1).toString() + 'px)';
  }

  bool _resizeStarted;
  int _resizeStartX;
  int _initialPositionX;
  Element _splitter;
  Element _splitterHandle;
  Element _leftView;
  Element _rightView;
  bool _horizontal;
}
