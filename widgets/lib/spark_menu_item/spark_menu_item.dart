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
  @published String src = "";
  /// Size of the icon.
  @published String iconsize = "24";
  /// Specifies the label for the menu item.
  @published String label = "";

  @observable bool isHovered = false;

  SparkMenuItem.created(): super.created() {
    // BUG: Use mouse events instead of :hover because Chrome fails to remove
    // :hover from an element after it's clicked and programmatically moved from
    // under the mouse, as is the case with our auto-closing spark-menu.
    bindCssClass(this, 'highlighted', this, 'isHovered');
    onMouseOver.listen((_) => isHovered = true);
    onMouseOut.listen((_) => isHovered = false);
  }
}
