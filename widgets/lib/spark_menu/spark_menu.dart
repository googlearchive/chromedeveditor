// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.menu;

import 'package:polymer/polymer.dart';

import '../spark_selector/spark_selector.dart';

// Ported from Polymer Javascript to Dart code.

@CustomTag("spark-menu")
class SparkMenu extends SparkSelector {
  SparkMenu.created(): super.created();

  // TODO(terry): Work around because changed events aren't handled up the
  //              sub-chain.
  void targetChanged(old) => super.targetChanged(old);
  void selectedItemChanged() => super.selectedItemChanged();
  void selectedChanged() => super.selectedChanged();
  void selectionSelect(e, detail) => super.selectionSelect(e, detail);
}
