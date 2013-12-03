/**
 * Copyright 2013 The Polymer Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be found
 * in the LICENSE file.
 */

library spark_widgets.menu_button;

import 'package:polymer/polymer.dart';

// Ported from Polymer Javascript to Dart code.

@CustomTag("spark-menu-button")
class SparkMenuButton extends PolymerElement {
  @observable String src = "";
  @observable int selected = 0;
  @observable bool opened = false;
  @observable bool responsive = false;
  @observable String valign = 'center';
  @observable String selectedClass = "";

  SparkMenuButton.created(): super.created();

  //* Toggle the opened state of the dropdown.
  void toggle() {
    opened = !opened;
  }

  //* Returns the selected item.
  String get selection {
    var menu = $['overlayMenu'];
    assert(menu != null);
    return menu.selection;
  }
}
