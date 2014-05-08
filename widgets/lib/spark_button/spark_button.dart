// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.button;

import 'package:polymer/polymer.dart';

import '../common/spark_widget.dart';

@CustomTag('spark-button')
class SparkButton extends SparkWidget {
  @published bool primary = false;
  @published bool enabled = true;
  @published bool large = false;
  @published bool small = false;
  @published bool noPadding = false;

  SparkButton.created() : super.created();

  @override
  void enteredView() {
    _setClasses();
    changes.listen((_) => _setClasses());
  }

  void _setClasses() {
    $['button'].classes
        ..toggle('btn-primary', primary)
        ..toggle('btn-default', !primary)
        ..toggle('enabled', enabled)
        ..toggle('disabled', !enabled)
        ..toggle('btn-lg', large)
        ..toggle('btn-sm', small);
  }
}
