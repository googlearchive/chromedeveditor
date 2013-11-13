// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.splitter;

import 'dart:html';
import 'package:polymer/polymer.dart';

@CustomTag('spark-splitter')
class SparkSplitter extends HtmlElement with Polymer, Observable {
  /// Possible values are "left", "right", "up" and "down".
  @observable String direction = 'left';
  /// Locks the split bar so it can't be dragged.
  @observable bool locked = false;

  static const _DIM_HEIGHT = 0, _DIM_WIDTH = 1;

  HtmlElement _target;
  bool _isNext;
  bool _horizontal;
  int _dimension;
  bool _isDragged = false;

  SparkSplitter.created() : super.created() {
    onMouseDown.listen(dragStart);
    onMouseMove.listen(drag);
    onMouseUp.listen(dragEnd);
    // TODO(sergeygs): Switch to using onDrag* instead of onMouse* once support
    // has been added to Polymer Dart.
    //onDragStart.listen(dragStart);
    //onDrag.listen(drag);
    //onDragEnd.listen(dragEnd);

    directionChanged();
  }

  void directionChanged() {
    _isNext = direction == 'right' || direction == 'down';
    _horizontal = direction == 'up' || direction == 'down';
    _dimension = _horizontal ? _DIM_HEIGHT : _DIM_WIDTH;
    update();
  }

  void update() {
    _target = _isNext ? nextElementSibling : previousElementSibling;
    classes.toggle('horizontal', _horizontal);
  }

  int getTargetDimension() {
    final style = _target.getComputedStyle();
    final dimStr = (_dimension == _DIM_HEIGHT) ? style.height : style.width;
    final dim = int.parse(dimStr.replaceFirst('px', ''));
    return dim;
  }

  void setTargetDimension(int dimension) {
    final dim = '${dimension}px';
    if (_dimension == _DIM_HEIGHT) {
      _target.style.height = dim;
    } else {
      _target.style.width = dim;
    }
  }

  void dragStart(MouseEvent e) {
    update();
    classes.add('active');
    _isDragged = true;
  }

  void drag(MouseEvent e) {
    if (_isDragged && !locked) {
      final int delta = _horizontal ? e.movement.y : e.movement.x;
      if (delta != null) {
        setTargetDimension(getTargetDimension() + (_isNext ? -delta : delta));
      }
    }
  }

  void dragEnd(MouseEvent e) {
    classes.remove('active');
    _isDragged = false;
  }
}
