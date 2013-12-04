// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.icon;

import 'package:polymer/polymer.dart';

import '../src/widget.dart';

// Ported from Polymer Javascript to Dart code.
@CustomTag("spark-icon")
class SparkIcon extends Widget {
  /// URL of an image for the icon.
  @published String src = "";

  /// Size of the icon defaults to 24.
  @published String size = "24";

  SparkIcon.created(): super.created();
}
