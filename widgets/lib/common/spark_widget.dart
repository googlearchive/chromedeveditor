// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets;

import 'dart:html';

import 'package:polymer/polymer.dart';

bool IS_DART2JS = identical(1, 1.0);

// NOTE: This SparkWidget element is not intended to use directly.
@CustomTag('spark-widget')
class SparkWidget extends PolymerElement {
  static const CSS_ENABLED = "enabled";
  static const CSS_DISABLED = "disabled";

  SparkWidget.created() : super.created();

  @override
  bool get applyAuthorStyles => true;

  String joinClasses(List<String> cls) => cls.join(" ");

  Element getShadowDomElement(String selectors) =>
      shadowRoot.querySelector(selectors);

  void focus() {
    // Only the first found element that has 'focused' attribute on it will be
    // actually focused; if there are more than one, the rest will be ignored.
    Element elementToFocus = this.getShadowDomElement('[focused]');
    if (elementToFocus != null) {
      elementToFocus.focus();
    }
  }
}
