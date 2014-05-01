// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.ui.polymer.goto_line_view;

import 'dart:async';
import 'dart:html';

import 'package:polymer/polymer.dart';
import 'package:spark_widgets/common/spark_widget.dart';

@CustomTag('goto-line-view')
class GotoLineView extends SparkWidget {
  Element _closeButton;
  Element _container;
  InputElement _queryText;

  StreamController<int> _triggeredController = new StreamController.broadcast();
  StreamController _closedController = new StreamController.broadcast();

  factory GotoLineView() => new Element.tag('goto-line-view');

  /**
   * Returns the currently entered line number. Note, this will throw an
   * exception if the line number is not parsable.
   */
  int get lineNumber => int.parse(_queryText.value);

  /**
   * Return whether the view is visible or not.
   */
  bool get open => _container.classes.contains('showing');

  /**
   * Make the view visible.
   */
  void show() {
    _selectQueryText();
    _container.classes.add('showing');
    _queryText.focus();
  }

  /**
   * Hide the view.
   */
  void hide() {
    if (!open) return;

    _container.classes.remove('showing');

    _closedController.add(null);
  }

  /**
   * This event is fired when the user hits return. The event is the text the
   * user entered in the text field.
   */
  Stream<int> get onTriggered => _triggeredController.stream;

  /**
   * Fires an event when the view is closed.
   */
  Stream get onClosed => _closedController.stream;

  GotoLineView.created() : super.created() {
    _closeButton = $['closeButton'];
    _container = $['container'];
    _queryText = $['queryText'];

    // Handle the escape key.
    _queryText.onKeyDown.listen((event) {
      if (event.keyCode == KeyCode.ESC) {
        hide();
      }
    });

    // Handle the enter key.
    _queryText.onKeyPress.listen((event) {
      if (event.keyCode == KeyCode.ENTER) {
        try {
          _triggeredController.add(lineNumber);
        } catch (e) {
          _selectQueryText();
        }
      }
    });

    _closeButton.onClick.listen((_) => hide());
  }

  void _selectQueryText() {
    Timer.run(() => _queryText.select());
  }
}
