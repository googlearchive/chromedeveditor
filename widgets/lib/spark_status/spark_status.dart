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

  Element _label;
  Element _throbber;
  Element _container;

  Timer _timer;

  // TODO(ussuri): Get rid of @published getters/setters for everything.

  @published bool get spinning => _spinning;

  @published set spinning(bool value) {
    _spinning = value;
    _update();
  }

  @published String get defaultMessage =>
      _defaultMessage == null ? '' : _defaultMessage;

  @published set defaultMessage(String value) {
    _defaultMessage = value;
    _update();
  }

  @published String get progressMessage =>
      _progressMessage == null ? '' : _progressMessage;

  @published set progressMessage(String value) {
    _progressMessage = value;
    _update();
  }

  @published String get temporaryMessage =>
      _temporaryMessage == null ? '' : _temporaryMessage;

  @published set temporaryMessage(String value) {
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

  @override
  void ready() {
    _container = getShadowDomElement('#status-container');
    _label = getShadowDomElement('#label');
    _throbber = getShadowDomElement('#throbber');
  }

  bool get _showingProgressMessage =>
      _temporaryMessage == null && _progressMessage != null;

  bool get _showingDefaultMessage =>
      _temporaryMessage == null && _progressMessage == null;

  bool get _showingTemporaryMessage => _temporaryMessage != null;

  void _update() {
    _throbber.classes.toggle('spinning',
        _spinning && (_temporaryMessage == null));
    final String text = _calculateMessage();
    _container.classes.toggle('hidden', text.isEmpty);
    _label.text = text;
  }

  String _calculateMessage() {
    if (_temporaryMessage != null) return _temporaryMessage;
    if (_progressMessage != null) return _progressMessage;
    if (_defaultMessage != null) return _defaultMessage;
    return '';
  }

  SparkStatus.created() : super.created();
}
