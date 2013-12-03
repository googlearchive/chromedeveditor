/**
 * Copyright 2013 The Polymer Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be found
 * in the LICENSE file.
 */

library spark_widgets.icon_button;

import 'package:polymer/polymer.dart';

// Ported from Polymer Javascript to Dart code.
@CustomTag("spark-icon-button")
class SparkIconButton extends PolymerElement {
  @observable String src = "";
  @observable bool active = false;

  SparkIconButton.created(): super.created();

  void activeChanged() {
    // TODO(sjmiles): 'class' attributes should have special handling
    //   for this common use case
    classes.toggle('selected', this.active);
  }
}
