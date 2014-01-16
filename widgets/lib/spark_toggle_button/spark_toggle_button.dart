// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.toggle_button;

import 'dart:html';
import 'dart:math';
import 'package:polymer/polymer.dart';

import '../common/spark_widget.dart';

// Ported from Polymer Javascript to Dart code.

// TODO(terry): Need to properly support touch.  Today there's an onclick
//               handler in the template to toggle the state - this shouldn't
//               be needed.
@CustomTag("spark-toggle-button")
class SparkToggleButton extends SparkWidget {
  /// Gets or sets the state, true is ON and false is OFF.
  @observable bool value = false;

  SparkToggleButton.created(): super.created();

  int _x;
  int _w;

  void toggle() {
    value = !value;
  }

  void valueChanged() {
    $['toggle'].classes.toggle('on', value);
  }

  void trackStart(Event e) {
    _w = $['toggle'].offsetWidth - clientWidth;
    $['toggle'].classes.add('dragging');
    // TODO(terry): Add e.preventTap() when PointerEvents supported.
  }

  void track(MouseEvent e) {
    _x = max(-_w, min(0, value ? e.client.x : e.client.y - _w));
    $['toggle'].style.left = '${_x}px';
  }

  void trackEnd() {
    $['toggle'].style.left = null;
    $['toggle'].classes.remove('dragging');
    value = _x.abs() < _w / 2;
//    // make valueChanged calls immediately
//    Platform.flush();
  }

  // TODO(terry): When touch events supported enable.
/*
  void flick(Event e) {
    this.value = e.xVelocity > 0;
    Platform.flush();
  }
*/
}
