/**
 * Copyright 2013 The Polymer Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be found
 * in the LICENSE file.
 */

library spark_widgets.menu;

import 'package:spark_widgets/spark-selector/spark-selector.dart';
import 'package:polymer/polymer.dart';

// Ported from Polymer Javascript to Dart code.

@CustomTag("spark-menu")
class SparkMenu extends SparkSelector {
  SparkMenu.created(): super.created();

  // TODO(terry): Work around because changed events aren't handled up the
  //              sub-chain.
  targetChanged(old) => super.targetChanged(old);
  selectedItemChanged() => super.selectedItemChanged();
  selectedChanged() => super.selectedChanged();
  void selectionSelect(e, detail) => super.selectionSelect(e, detail);
}
