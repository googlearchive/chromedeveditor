// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.ui.polymer.find_view;

import 'dart:async';
import 'dart:html';

import 'package:polymer/polymer.dart';
import 'package:spark_widgets/common/spark_widget.dart';

@CustomTag('find-view')
class FindView extends SparkWidget {
  String get queryText => ($['queryText'] as InputElement).value;
  set queryText(String value) => ($['queryText'] as InputElement).value = value;

  StreamController<String> _triggeredController = new StreamController.broadcast();
  StreamController _closedController = new StreamController.broadcast();

  factory FindView() => new Element.tag('find-view');

  /**
   * Return whether the view is visible or not.
   */
  bool get open => $['container'].classes.contains('showing');

  /**
   * Make the view visible.
   */
  void show() {
    $['container'].classes.add('showing');
    $['queryText'].focus();
  }

  /**
   * Hide the view.
   */
  void hide() {
    if (!open) return;

    $['container'].classes.remove('showing');

    _closedController.add(null);
  }

  /**
   * Select all the query text.
   */
  void selectQueryText() {
    Timer.run(() {
      ($['queryText'] as InputElement).select();
    });
  }

  /**
   * This event is fired when the user hits return. The event is the text the
   * user entered in the text field.
   */
  Stream<String> get onTriggered => _triggeredController.stream;

  /**
   * Fires an event when the view is closed.
   */
  Stream get onClosed => _closedController.stream;

  FindView.created() : super.created() {
    // Handle the escape key.
    $['queryText'].onKeyDown.listen((event) {
      if (event.keyCode == KeyCode.ESC) {
        hide();
      }
    });

    // Handle the enter key.
    $['queryText'].onKeyPress.listen((event) {
      if (event.keyCode == KeyCode.ENTER) {
        _triggeredController.add(queryText);
      }
    });

    $['closeButton'].onClick.listen((_) => hide());
  }
}
