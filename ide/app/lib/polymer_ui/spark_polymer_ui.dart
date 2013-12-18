// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_polymer.ui;

import 'dart:html';

import 'package:polymer/polymer.dart';

// BUG(ussuri): https://github.com/dart-lang/spark/issues/500
import '../../packages/spark_widgets/common/widget.dart';

import '../../spark_model.dart';

@CustomTag('spark-polymer-ui')
class SparkPolymerUI extends Widget {
  SparkPolymerUI.created() : super.created();

  void toggleDropdownMenu() {
    var menu = getShadowDomElement("#dropDownMenu");
    menu.style.display =
      menu.style.display == "block" ? "none" : "block";
  }

  void onMenuSelected(Event event, var detail) {
    final actionId = detail['item'];
    final action = SparkModel.instance.actionManager.getAction(actionId);
    assert(action != null);
    action.invoke();
  }

  void onThemeMinus(Event e) {
    SparkModel.instance.aceThemeManager.dec(e);
  }

  void onThemePlus(Event e) {
    SparkModel.instance.aceThemeManager.inc(e);
  }

  void onKeysMinus(Event e) {
    SparkModel.instance.aceKeysManager.dec(e);
  }

  void onKeysPlus(Event e) {
    SparkModel.instance.aceKeysManager.inc(e);
  }
}
