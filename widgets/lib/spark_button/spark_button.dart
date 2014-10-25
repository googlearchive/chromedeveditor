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
  @published bool flat = true;
  @published bool raised = false;
  @published bool round;
  @published bool primary;
  @published_reflected String padding;
  @published_reflected String hoverStyle;

  @published bool get disabled => attributes.containsKey('disabled');
  @published set disabled(bool value) => setAttr('disabled', value);

  @published bool active;
  @published String tooltip;
  @published String command;

  SparkButton.created() : super.created();

  @override
  void attached() {
    super.attached();

    // Make sure at most one of [raised] or [flat] is defined by the client.
    // TODO(ussuri): This is really clumsy. Find a better way to provide
    // mutually exclusive flags.
    assert(raised != true || flat != true);

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
      // TODO(ussuri): #2252.
      attributes['hoverStyle'] = 'background';
    }

    assert(['none', 'small', 'medium', 'large', 'huge'].contains(padding));
    assert(['background', 'foreground'].contains(hoverStyle));
  }

  void handleClick(event) {
    if (!disabled && command != null && command.isNotEmpty) {
      event.preventDefault();
      event.stopPropagation();
      fire('command', detail: {'command': command});
    }
  }
}
