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
  @published String viewTitle;
  @published String queryText;

  StreamController<bool> _triggeredController = new StreamController.broadcast();
  StreamController<bool> _closedController = new StreamController.broadcast();

  static FindView createIn(Element parent) {
    FindView view = new FindView();
    parent.children.add(view);
    return view;
  }

  factory FindView() => new Element.tag('find-view');

  // TODO: implement
  bool get open => true;

  void show() {
    $['container'].classes.add('showing');
    $['queryText'].focus();

    print('showing...');
  }

  void hide() {
    if (!open) return;

    // TODO: with style! animations
    $['container'].classes.remove('showing');

    print('hiding');

    _closedController.add(null);
  }

  /**
   * This event is fired when the user hits return. The return value is either
   * `true` (for a normal return key), or `false` if the user hit shift-return.
   */
  Stream<bool> get onTriggered => _triggeredController.stream;

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
        _triggeredController.add(event.shiftKey ? false : true);
      }
    });
  }
}
