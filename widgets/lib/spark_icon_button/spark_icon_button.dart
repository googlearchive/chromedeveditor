// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.icon_button;

import 'package:polymer/polymer.dart';

import '../common/spark_widget.dart';

// TODO(ussuri): Temporary. See the other TODO below.
import '../spark_icon/spark_icon.dart';

// Ported from Polymer Javascript to Dart code.
@CustomTag("spark-icon-button")
class SparkIconButton extends SparkWidget {
  @published String src = "";
  @published String tooltip = "";
  @published bool active = false;

  SparkIconButton.created(): super.created();

  void enteredView() {
    // TODO(ussuri): This is a temporary plug to make spark-icon see changes
    // in 'src' when run as deployed code. Just binding via {{src}} alone
    // wasn't detected during launch and the icon was blank. After a click,
    // it appeared.
    if (IS_DART2JS) {
      ($['icon'] as SparkIcon).src = src;
    }
  }

  void activeChanged() {
    // TODO(sjmiles): 'class' attributes should have special handling
    //   for this common use case
    classes.toggle('selected', this.active);
  }
}
