// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.progress;

import 'dart:async';
import 'dart:html';

import 'package:polymer/polymer.dart';

import '../common/spark_widget.dart';

@CustomTag("spark-progress")
class SparkProgress extends SparkWidget {
  Element _progressDiv;

  bool _indeterminate;
  num _value;
  bool _visible;

  StreamController _cancelController = new StreamController.broadcast();

  /**
   * A value between 0 and 100.
   */
  @published
  num get value => indeterminate ? 100 : _value;
  set value(num val) {
    _value = val.clamp(0, 100);
  }

  @published
  bool get indeterminate => _indeterminate != null ? _indeterminate : false;
  set indeterminate(bool val) {
    _indeterminate = val == true;

    if (_progressDiv != null) {
      _progressDiv.classes.toggle('progress-striped', _indeterminate);
      _progressDiv.classes.toggle('active', _indeterminate);
    }
  }

  @published
  bool get visible => _visible != null ? _visible : true;
  set visible(bool val) {
    _visible = val;

    style.visibility = _visible ? 'visible' : 'hidden';
  }

  @published bool showProgressMessage = false;

  @published String progressMessage = '';

  @published bool showCancel = false;

  Stream get onCancelled => _cancelController.stream;

  void cancelClickHandler(evt) => _cancelController.add(null);

  SparkProgress.created() : super.created() {
    _progressDiv = $['progressDiv'];
    indeterminate = indeterminate;
    visible = visible;
  }
}
