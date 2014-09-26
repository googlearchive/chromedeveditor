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

  bool get preventDispose => true;

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
    asyncFire('closed');
  }

  /**
   * This event is fired when the user hits return. The event's `detail` field
   * contains the line numer the user has entered.
   */
  Stream get onTriggered => on['triggered'];

  /**
   * Fires an event when the view is closed.
   */
  Stream get onClosed => on['closed'];

  GotoLineView.created() : super.created();

  @reflectable
  void handleKeyDown(KeyboardEvent event) {
    // Handle the escape key.
    if (event.keyCode == KeyCode.ESC) {
      hide();
    }
  }

  @reflectable
  void handleKeyPress(KeyboardEvent event) {
    // Handle the enter key.
    if (event.keyCode == KeyCode.ENTER) {
      try {
        asyncFire('triggered', detail: lineNumber);
      } catch (e) {
        _selectQueryText();
      }
    }
  }

  Element get _container => $['container'];

  InputElement get _queryText => $['queryText'];

  void _selectQueryText() {
    Timer.run(() => _queryText.select());
  }
}
