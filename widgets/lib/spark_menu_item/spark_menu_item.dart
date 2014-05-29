// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.menu_item;

import 'package:polymer/polymer.dart';

import '../common/spark_widget.dart';

// Ported from Polymer Javascript to Dart code.

@CustomTag("spark-menu-item")
class SparkMenuItem extends SparkWidget {
  /// URL image for the icon associated with this menu item.
  @published String icon = "";

  /// Size of the icon.
  @published String iconSize = '24px';

  /// Specifies the label for the menu item.
  @published String label = "";

  /// Description for this menu, usually used for a keybinding description.
  @published String description = "";

  SparkMenuItem.created(): super.created();

  @override
  void enteredView() {
    super.enteredView();
  }
}
