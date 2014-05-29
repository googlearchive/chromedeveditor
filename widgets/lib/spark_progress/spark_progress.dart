// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.progress;

import 'dart:async';
import 'dart:html';

import 'package:polymer/polymer.dart';

import '../common/spark_widget.dart';

/**
 * A Polymer component to display a progress bar.
 *
 * The progress bar can have an optional textual message, and an optional cancel
 * button. The progress can either be determinate - from 0 to 100 - or
 * indeterminate.
 */
@CustomTag("spark-progress")
class SparkProgress extends SparkWidget {
  StreamController _cancelController = new StreamController.broadcast();
  Element _progressDiv;

  num _value = 0;
  bool _visible = true;

  /// A value between 0 and 100.
  @published
  num get value => indeterminate ? 100 : _value;

  @published
  set value(num val) {
    _value = val.clamp(0, 100);
  }

  /// Whether to display the progress component or not.
  @published
  bool get visible => _visible;

  @published
  set visible(bool val) {
    _visible = val;

    style.visibility = _visible ? 'visible' : 'hidden';
  }

  /// Whether the progress component should be indeterminate or not.
  @published bool indeterminate = false;

  void indeterminateChanged() {
    if (_progressDiv != null) {
      _progressDiv.classes.toggle('progress-striped', indeterminate);
      _progressDiv.classes.toggle('active', indeterminate);
    }
  }

  /// Whether to display a textual progress message.
  @published bool showProgressMessage = false;

  /// The textual progress message.
  @published String progressMessage = ' ';

  /// Whether to show a cancel button.
  @published bool showCancel = false;

  SparkProgress.created() : super.created();

  @override
  void enteredView() {
    _progressDiv = $['progressDiv'];

    // TODO(ussuri): Investigate why this explicit assignment is necessary.
    visible = visible;
    indeterminate = indeterminate;
  }

  Stream get onCancelled => on['cancelled'];

  /// Public for Polymer.
  void cancelClickHandler(_) => asyncFire('cancelled');
}
