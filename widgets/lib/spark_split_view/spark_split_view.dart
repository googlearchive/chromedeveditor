// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.split_view;

import 'dart:html';

import 'package:polymer/polymer.dart';

import '../common/spark_widget.dart';
import '../spark_splitter/spark_splitter.dart';

@CustomTag('spark-split-view')
class SparkSplitView extends SparkWidget {
  /// These are just wires into the enclosed [SparkSplitter]. See that class
  /// for the description of the attributes.
  @published String direction = 'left';
  @published int splitterSize = 8;
  @published bool splitterHandle = true;
  @published int targetSize;
  @published int minTargetSize = 0;
  @published int maxTargetSize = 100000;
  @published bool locked = false;

  SparkSplitter _splitter;

  /// Constructor.
  SparkSplitView.created() : super.created();

  @override
  void enteredView() {
    super.enteredView();
    // Make sure there are exactly 2 children inserted in the instantiation
    // site. When we're enclosed in another element and passed down its
    // <content>, we need to dive into that <content> to look at its distributed
    // nodes.
    assert(children.length == 2 ||
           (children.length == 1 &&
            children[0] is ContentElement &&
            SparkWidget.inlineNestedContentNodes(children[0]).length == 2
           )
    );
    _splitter = $['splitter'];
  }

  void targetSizeChanged() {
    // TODO(ussuri): This was critical for correct propagation of the client's
    // changes in [targetSize] to the enclosed splitter. Investigate.
    _splitter.targetSize = targetSize;
    if (IS_DART2JS) {
      // TODO(ussuri): In the deployed code, even the above wasn't enough.
      _splitter.targetSizeChanged();
    }
  }

  /**
   * Re-fire an update event from the splitter for explicitness.
   */
  void splitterUpdateHandler(CustomEvent e, var detail) {
    e..stopImmediatePropagation()..preventDefault();
    asyncFire('update', detail: detail);
  }
}
