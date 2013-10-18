// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.splitview;

import 'dart:html';
import 'html_utils.dart';

// splitview
// +- .left
// +- .splitter
// +- .right

class SplitView {
  bool _resizeStarted = false;
  int _resizeStartX;
  int _initialPositionX;
  Element _splitView;
  Element _splitter;
  Element _splitterHandle;
  Element _leftView;
  Element _rightView;
  bool _horizontal;
  int _leftMinSize = 0;
  int _rightMinSize = 0;

  SplitView(Element splitView) {
    _splitView = splitView;
    _leftView = splitView.query('.left');
    _rightView = splitView.query('.right');

    _horizontal = (getAbsolutePosition(_leftView).x == getAbsolutePosition(_rightView).x);

    String minSizeString = _leftView.getAttribute('minsize');
    if (minSizeString != null) {
      _leftMinSize = int.parse(minSizeString);
    }
    minSizeString = _leftView.getAttribute('minsize');
    if (minSizeString != null) {
      _rightMinSize = int.parse(minSizeString);
    }

    int splitterMargin = 3;
    _splitter = new DivElement();
    _splitter.classes.add('splitter');
    _splitter.style.height = '100%';
    _splitter.style.width = '1px';
    _splitter.style.position = 'absolute';
    _splitView.children.add(_splitter);
    _splitterHandle = new DivElement();
    _splitterHandle.classes.add('splitter-handle');
    _splitterHandle.style.position = 'relative';
    _splitterHandle.style.height = '100%';
    _splitterHandle.style.cursor = 'ew-resize';
    _splitterHandle.style.zIndex = '100';
    _splitter.children.add(_splitterHandle);

    if (_isVertical()) {
      _splitterHandle.style.left = (-splitterMargin).toString() + 'px';
      _splitterHandle.style.width = (splitterMargin * 2).toString() + 'px';
    } else {
      _splitterHandle.style.left = (-splitterMargin).toString() + 'px';
      _splitterHandle.style.width = (splitterMargin * 2).toString() + 'px';
    }
    
    _setSplitterPosition(_leftView.clientWidth);

    document.onMouseDown.listen(_resizeDownHandler);
    document.onMouseMove.listen(_resizeMoveHandler);
    document.onMouseUp.listen(_resizeUpHandler);
    print('splitview');
  }

  bool _isHorizontal() {
    return _splitter.offsetWidth > _splitter.offsetHeight;
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
}
