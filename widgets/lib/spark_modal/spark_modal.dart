// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.modal;

import 'dart:html';
import 'package:polymer/polymer.dart';

import '../spark_overlay/spark_overlay.dart';

// Ported from Polymer Javascript to Dart code.

@CustomTag("spark-modal")
class SparkModal extends SparkOverlay {
  @override
  void keydownHandler(KeyboardEvent e) {
    final int ESCAPE_KEY = 27;
    if (e.keyCode == ESCAPE_KEY) {
      this.opened = false;
      e.stopImmediatePropagation();
      e.preventDefault();
    }
  }

  SparkModal.created(): super.created();
}
