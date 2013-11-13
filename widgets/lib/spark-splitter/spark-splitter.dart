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
  int _size;

  SparkSplitter.created() : super.created() {
    onDragStart.listen(dragStart);
    onDrag.listen(drag);
    onDragEnd.listen(dragEnd);

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
    return int.parse((_dimension == _DIM_HEIGHT) ? style.height : style.width);
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
    _size = getTargetDimension();
  }

  void drag(MouseEvent e) {
    if (!locked) {
      final delta = _horizontal ? e.movement.y : e.movement.x;
      setTargetDimension(_size + (_isNext ? -delta : delta));
    }
  }

  void dragEnd(MouseEvent e) {
    classes.remove('active');
  }
}
