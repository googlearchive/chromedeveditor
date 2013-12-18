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
  SparkModel app;

  factory SparkPolymerUI(SparkModel app) {
    SparkPolymerUI ui = new Element.tag('spark-polymer-ui');
    ui.app = app;
    return ui;
  }

  SparkPolymerUI.created() : super.created();

  void toggleDropdownMenu() {
    var menu = getShadowDomElement("#dropDownMenu");
    menu.style.display =
      menu.style.display == "block" ? "none" : "block";
  }

  void onMenuSelected(Event event, Map<String, dynamic> detail) {
    final actionId = detail['item'].attributes['actionId'];
    final action = app.actionManager.getAction(actionId);
    assert(action != null);
    action.invoke();
  }
}
