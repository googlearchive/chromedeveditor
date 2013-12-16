// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_polymer.ui;

import 'dart:html';
import 'package:polymer/polymer.dart';
import 'package:spark_widgets/common/widget.dart';

import '../../spark_polymer.dart';

@CustomTag('spark-polymer-ui')
class SparkPolymerUI extends Widget {
  SparkPolymerUI.created() : super.created();

  void toggleDropdownMenu() {
    var menu = getShadowDomElement("#dropDownMenu");
    menu.style.display =
      menu.style.display == "block" ? "none" : "block";
  }

  void onMenuSelected(CustomEvent event, Map<String, dynamic> detail) {
    // TODO(ussuri): this could be bound in the HTML via
    // `@observable SparkPolymer app` initialized to [spark].
    // But [spark] is initialized asynchronously and that happens to be later
    // than any of the events associated with this object. Find a way to do
    // that.
    spark.onMenuSelected(event, detail);
  }
}
