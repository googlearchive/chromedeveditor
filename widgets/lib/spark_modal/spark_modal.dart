// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.modal;

import 'package:polymer/polymer.dart';

import '../spark_overlay/spark_overlay.dart';

// Ported from Polymer Javascript to Dart code.

@CustomTag("spark-modal")
class SparkModal extends SparkOverlay {
  SparkModal.created(): super.created();
}
