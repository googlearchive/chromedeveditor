// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_polymer.ui;

import 'package:polymer/polymer.dart';

// BUG(ussuri): https://github.com/dart-lang/spark/issues/500
import '../../packages/spark_widgets/common/widget.dart';

@CustomTag('spark-polymer-ui')
class SparkPolymerUI extends Widget {
  SparkPolymerUI.created() : super.created();

  void toggleDropdownMenu() {
    var menu = getShadowDomElement("#dropDownMenu");
    menu.style.display =
      menu.style.display == "block" ? "none" : "block";
  }
}
