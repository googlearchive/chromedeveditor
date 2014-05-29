// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.spark_dialog_button;

import 'package:polymer/polymer.dart';

import '../spark_button/spark_button.dart';

@CustomTag('spark-dialog-button')
class SparkDialogButton extends SparkButton {
  @published bool submit = false;
  @published bool cancel = false;
  @published bool dismiss = false;

  SparkDialogButton.created() : super.created();

  @override
  void enteredView() {
    super.enteredView();

    // At most one of [submit] and [cancel] can be true.
    assert([submit, cancel, dismiss].where((e) => e == true).length <= 1);

    if (submit || dismiss) {
      if (primary == null) primary = true;
      if (raised == null) raised = true;
    } else {
      if (primary == null) primary = false;
      if (flat == null) flat = true;
    }
    if (submit || dismiss || cancel) {
      // spark-overlay analyzes all clicks and auto-closes if the clicked
      // element has [overlayToggle] attribute.
      attributes['overlayToggle'] = '';
    }
  }
}
