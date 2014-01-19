// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.status;

import 'dart:async';
import 'dart:html';

import 'package:polymer/polymer.dart';

import '../common/spark_widget.dart';

/**
 * This status widget can:
 *
 * * show a default message ([defaultMessage])
 * * show a progress... message ([progressMessage]), and optional spinner
 * * show a temporary message ([temporaryMessage)
 *
 * The progress message is generally used with the spinner control. The
 * temporary message automatically clears itself after a brief period. The
 * control shows, preferentially in this order, the:
 *
 * * temporary message, if any
 * * or progress message, if any
 * * or default message, if any
 */
@CustomTag('spark-status')
class SparkStatus extends SparkWidget {
  bool _spinning = false;
  String _defaultMessage;
  String _progressMessage;
  String _temporaryMessage;

  Timer _timer;

  @published bool get spinning => _spinning;

  set spinning(bool value) {
    _spinning = value;

    Element element = getShadowDomElement('.throbber');
    element.classes.toggle('spinning', _spinning);
  }

  @published String get defaultMessage => _defaultMessage == null ? '' : _defaultMessage;

  set defaultMessage(String value) {
    _defaultMessage = value;
    _update();
  }

  @published String get progressMessage => _progressMessage == null ? '' : _progressMessage;

  set progressMessage(String value) {
    _progressMessage = value;
    _update();
  }

  @published String get temporaryMessage => _temporaryMessage == null ? '' : _temporaryMessage;

  set temporaryMessage(String value) {
    if (_timer != null) {
      _timer.cancel();
    }

    _temporaryMessage = value;
    _update();

    if (value != null) {
      _timer = new Timer(new Duration(seconds: 3), () {
        temporaryMessage = null;
      });
    }
  }

  bool get showingProgressMessage =>
      _temporaryMessage == null && _progressMessage != null;

  bool get showingDefaultMessage =>
      _temporaryMessage == null && _progressMessage == null;

  bool get showingTemporaryMessage => _temporaryMessage != null;

  void _update() {
    Element element = getShadowDomElement('.label');
    element.classes.toggle('default', showingDefaultMessage);
    element.classes.toggle('progressStyle', showingProgressMessage);
    element.classes.toggle('temporary', showingTemporaryMessage);
    element.innerHtml = _calculateMessage();
  }

  String _calculateMessage() {
    if (_temporaryMessage != null) return _temporaryMessage;
    if (_progressMessage != null) return _progressMessage;
    if (_defaultMessage != null) return _defaultMessage;
    return '';
  }

  SparkStatus.created() : super.created();
}
