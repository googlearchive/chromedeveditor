// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.split_view;

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
  @published bool locked = false;
  @published SplitterUpdateFunction onUpdate;

  /// Constructor.
  SparkSplitView.created() : super.created();

  @override
  void enteredView() {
    super.enteredView();
    // The rest of the code might work even if there are more than 2 children,
    // but would create hard-to-understand results on the client side.
    assert(children.length == 2);
  }

  /**
   * Set the current splitter location.
   */
  set targetSize(num val) {
    ($['splitter'] as SparkSplitter).targetSize = val;
  }
}
