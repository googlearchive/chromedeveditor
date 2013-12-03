/**
 * Copyright 2013 The Polymer Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be found
 * in the LICENSE file.
 */

library spark_widgets.toolbar;

import 'package:polymer/polymer.dart';

// Ported from Polymer Javascript to Dart code.
@CustomTag("spark-toolbar")
class SparkToolbar extends PolymerElement {
  @observable bool responsive = false;
  @observable bool touch = false;

  SparkToolbar.created(): super.created();

  String get touchAction =>  touch ? "" : "none";
}
