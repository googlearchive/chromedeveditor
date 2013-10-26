// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.widgets.button;

import 'package:polymer/polymer.dart';

@CustomTag('spark-button')
class SparkButton extends PolymerElement {
  @observable bool active = false;
  SparkButton.created() : super.created() {
  }
}
