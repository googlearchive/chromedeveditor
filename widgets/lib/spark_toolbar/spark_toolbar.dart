// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.toolbar;

import 'dart:html';

import 'package:polymer/polymer.dart';

import '../common/spark_widget.dart';

@CustomTag("spark-toolbar")
class SparkToolbar extends SparkWidget {
  /// The client must specify one, and only one, of [vertical] and [horizontal].
  @published bool horizontal = false;
  @published bool vertical = false;
  // TODO(ussuri): Default values don't work on the CSS: force client to specify.
  @published String justify;
  @published String spacing;
  @published bool collapseEmpty = false;

  SparkToolbar.created(): super.created();

  @override
  void attached() {
    super.attached();

    assert(horizontal || vertical);
    assert(horizontal != vertical);
    assert(['left', 'right', 'center', 'spaced', 'edges'].contains(justify));
    assert(['small', 'medium', 'large', 'none'].contains(spacing));

    if (collapseEmpty) {
      final Iterable<Element> content =
          SparkWidget.inlineNestedContentNodes($['content']);
      final bool somethingToShow =
          content.any((e) => e.getComputedStyle().display != 'none');
      if (!somethingToShow) {
        style.display = 'none';
      }
    }
  }
}
