// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.ui.polymer.find_view;

import 'dart:html';

import 'package:polymer/polymer.dart';
import 'package:spark_widgets/common/spark_widget.dart';

@CustomTag('find-view')
class FindView extends SparkWidget {
  @observable String viewTitle;
  @observable String queryText;

  static createIn(Element parent) {
    FindView view = new FindView();
    parent.children.add(view);
    return view;
  }

  factory FindView() => new Element.tag('find-view');

  FindView.created() : super.created();
}
