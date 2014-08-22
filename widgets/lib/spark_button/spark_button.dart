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
  @published_reflected String padding;
  @published_reflected String hoverStyle;
  @published bool disabled;
  @published bool active;
  @published String tooltip;

  SparkButton.created() : super.created();

  @override
  void attached() {
    super.attached();

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

    if (padding == null) {
      padding = 'medium';
    }

    if (hoverStyle == null) {
      hoverStyle = 'background';
    }

    assert(['none', 'small', 'medium', 'large', 'huge'].contains(padding));
    assert(['background', 'foreground'].contains(hoverStyle));
  }
}
