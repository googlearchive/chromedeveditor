// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.icon_button;

import 'package:polymer/polymer.dart';

import '../src/widget.dart';

// Ported from Polymer Javascript to Dart code.
@CustomTag("spark-icon-button")
class SparkIconButton extends Widget {
  @published String src = "";
  @published bool active = false;

  SparkIconButton.created(): super.created();

  void activeChanged() {
    // TODO(sjmiles): 'class' attributes should have special handling
    //   for this common use case
    classes.toggle('selected', this.active);
  }
}
