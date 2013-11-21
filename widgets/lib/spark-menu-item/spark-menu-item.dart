/**
 * Copyright 2013 The Polymer Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be found
 * in the LICENSE file.
 */

library spark_widgets.menu_item;

import 'package:polymer/polymer.dart';

// Ported from Polymer Javascript to Dart code.

@CustomTag("spark-menu-item")
class SparkMenuItem extends PolymerElement {
  /// URL image for the icon associated with this menu item.
  @observable String src = "";

  /// Size of the icon.
  @observable String iconsize = "24";

  /// Specifies the label for the menu item.
  @observable String label = "";

  SparkMenuItem.created(): super.created();
}
