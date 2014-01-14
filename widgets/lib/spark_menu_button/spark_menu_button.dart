// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.menu_button;

import 'package:polymer/polymer.dart';

import '../common/widget.dart';
import '../spark_menu/spark_menu.dart';

import '../spark_icon_button/spark_icon_button.dart';
import '../spark_overlay/spark_overlay.dart';

// Ported from Polymer Javascript to Dart code.

@CustomTag("spark-menu-button")
class SparkMenuButton extends Widget {
  @published String src = "";
  @published dynamic selected;
  @published String valueattr = "";
  @published bool opened = false;
  @published bool responsive = false;
  @published String valign = "center";
  @published String selectedClass = "";

  SparkMenuButton.created(): super.created();

  void enteredView() {
    ($['button'] as SparkIconButton).deliverChanges();
//    ($['button'] as SparkIconButton).src = src;
  }

  //* Toggle the opened state of the dropdown.
  void toggle() {
    print("toggle");
    SparkMenu menu = $['overlayMenu'];
    menu.clearSelection();
    opened = !opened;
    // TODO(ussuri): This is a temporary plug to make spark-overlay see changes
    // in 'opened'. Just binding to it via {{opened}} in HTML doesn't work in
    // deployed code in Chrome.
//    ($['button'] as SparkIconButton).active = opened;
//    ($['overlay'] as SparkOverlay).opened = opened;
//    ($['overlay'] as SparkOverlay).toggleForce();
    ($['overlay'] as SparkOverlay).deliverChanges();
  }

  //* Returns the selected item.
  String get selection {
    var menu = $['overlayMenu'];
    assert(menu != null);
    return menu.selection;
  }
}
