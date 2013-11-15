// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.select;

import 'dart:html';
import 'package:polymer/polymer.dart';

@CustomTag('spark-select')
class SparkSelect extends HtmlElement with Polymer, Observable {
  @published List items = [];
  @published int selected = 0;

  @published String text_color = 'black';
  @published String color = 'white';
  @published String hover_color = 'white';

  SparkSelect.created() : super.created() {
  }
}
