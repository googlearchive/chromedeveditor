// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.menu_button;

import 'dart:html';

import 'package:polymer/polymer.dart';

import '../common/spark_widget.dart';
import '../spark_menu/spark_menu.dart';

// Ported from Polymer Javascript to Dart code.

// TODO(ussuri): Temporary. See the comment below.
import '../spark_overlay/spark_overlay.dart';

@CustomTag("spark-menu-button")
class SparkMenuButton extends SparkWidget {
  @published String src = "";
  @published dynamic selected;
  @published String valueattr = "";
  @published bool opened = false;
  @published bool responsive = false;
  @published String valign = "center";
  @published String selectedClass = "";

  SparkMenuButton.created(): super.created();

  //* Toggle the opened state of the dropdown.
  void toggle() {
    ($['overlayMenu'] as SparkMenu).clearSelection();
    opened = !opened;

    // TODO(ussuri): This is a temporary plug to make spark-overlay see changes
    // in 'opened' when run as deployed code. Just binding via {{opened}} alone
    // isn't detected and the menu doesn't open.
    if (IS_DART2JS) {
      ($['overlay'] as SparkOverlay).opened = opened;
    }
  }

  //* Handle the on-opened event from the dropdown. It will be fired e.g. when
  //* mouse is clicked outside the dropdown (with autoClosedDisabled == false).
  void onOpened(CustomEvent e) {
    // Autoclosing is the only event we're interested in.
    if (e.detail == false) {
      opened = false;
    }
  }

  //* Returns the selected item.
  String get selection => ($['overlayMenu'] as SparkMenu).selection;
}
