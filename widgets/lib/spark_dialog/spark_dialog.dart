// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.dialog;

import 'dart:html';

import 'package:polymer/polymer.dart';

import '../spark_modal/spark_modal.dart';
import '../common/spark_widget.dart';

@CustomTag('spark-dialog')
class SparkDialog extends SparkWidget {
  // TODO(ussuri): Replace with a regular published property (BUG #2252).
  /**
   * The title of the dialog.
   */
  @published String get title => _title;
  @published set title(String value) {
    _title = value;
    if (_titleElement != null) _titleElement.text = value;
  }

  /**
   * The kind of animation that the overlay should perform on open/close.
   */
  @published String animation = 'scale-slideup';

  bool _activityVisible = false;

  SparkModal _modal;
  String _title = '';
  Element _titleElement;

  SparkDialog.created() : super.created();

  @override
  void enteredView() {
    super.enteredView();

    _modal = $['modal'];

    _titleElement = $['title'];
    title = _title;

    $['progress'].classes.toggle('hidden', !_activityVisible);
    SparkWidget.enableKeyboardEvents(_modal);
  }

  void show() {
    if (!_modal.opened) {
      _modal.toggle();
    }
  }

  void hide() {
    if (_modal.opened) {
      _modal.toggle();
    }
  }

  bool get activityVisible => _activityVisible;

  void set activityVisible(bool visible) {
    _activityVisible = visible;
    $['progress'].classes.toggle('hidden', !_activityVisible);
  }
}
