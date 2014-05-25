// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.toolbar;

import 'package:polymer/polymer.dart';

import '../common/spark_widget.dart';

@CustomTag("spark-toolbar")
class SparkToolbar extends SparkWidget {
  @published String size = '100%ß';
  @published String direction = 'horizontal';
  @published bool flex = false;

  SparkToolbar.created(): super.created();

  @override
  void enteredView() {
    assert(['horizontal', 'vertical'].contains(direction));

    if (direction == 'horizontal') {
      style.height = size;
    } else {
      style.width = size;
    }
  }
}
