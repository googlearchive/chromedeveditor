// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.button;

import 'package:polymer/polymer.dart';

import '../common/spark_widget.dart';

// TODO(ussuri): Add comments.

@CustomTag('spark-button')
class SparkButton extends SparkWidget {
  // [flat] is the default.
  @published bool flat;
  @published bool raised;
  @published bool round;
  @published bool primary;
  @published String padding;
  @published bool disabled;
  @published bool active;

  SparkButton.created() : super.created();

  @override
  void enteredView() {
    super.enteredView();

    // Make sure at most one of [raised] or [flat] is defined by the client.
    // TODO(ussuri): This is really clumsy. Find a better way to provide
    // mutually exclusive flags.
    assert(raised == null || flat == null);
    if (flat != null) {
      raised = !flat;
    } else if (raised != null) {
      flat = !raised;
    } else {
      flat = true;
    }

    assert(['none', 'small', 'medium', 'large', 'huge'].contains(padding));
  }
}
