// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.button;

import 'package:polymer/polymer.dart';

import '../src/widget.dart';

@CustomTag('spark-button')
class SparkButton extends Widget {
  @observable bool primary = false;
  @observable bool active = false;
  @observable String btnClass = "btn btn-default";

  SparkButton.created() : super.created();

  void primaryChanged() {
    if (primary) {
      btnClass = "btn btn-primary";
    } else {
      btnClass = "btn btn-default";
    }
  }
}
