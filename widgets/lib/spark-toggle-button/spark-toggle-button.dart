/**
 * Copyright 2013 The Polymer Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be found
 * in the LICENSE file.
 */

library spark_widgets.toggle_button;

import 'dart:html';
import 'dart:math';
import 'package:polymer/polymer.dart';

// Ported from Polymer Javascript to Dart code.

// TODO(terry): Need to properly support touch.  Today there's an onclick
//               handler in the template to toggle the state - this shouldn't
//               be needed.
@CustomTag("spark-togglebutton")
class SparkToggleButton extends PolymerElement {
  /// Gets or sets the state, true is ON and false is OFF.
  @observable bool value = false;

  SparkToggleButton.created(): super.created();

  int x;
  int w;

  void toggle() {
    value = !value;
  }

  void valueChanged() {
    $['toggle'].classes.toggle('on', value);
  }

  void trackStart(Event e) {
    w = $['toggle'].offsetWidth - clientWidth;
    $['toggle'].classes.add('dragging');
    // TODO(terry): Add e.preventTap() when PointerEvents supported.
  }

  void track(MouseEvent e) {
    x = max(-w, min(0, value ? e.client.x : e.client.y - w));
    $['toggle'].style.left = '${x}px';
  }

  void trackEnd() {
    $['toggle'].style.left = null;
    $['toggle'].classes.remove('dragging');
    value = x.abs() < w / 2;
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
