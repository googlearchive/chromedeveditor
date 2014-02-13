// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets;

import 'dart:html';

import 'package:polymer/polymer.dart';

const bool IS_DART2JS = identical(1, 1.0);

// NOTE: This SparkWidget element is not intended to use directly.
@CustomTag('spark-widget')
class SparkWidget extends PolymerElement {
  static const CSS_ENABLED = "enabled";
  static const CSS_DISABLED = "disabled";

  // Popular key codes
  static const DOWN_KEY = 40;
  static const UP_KEY = 38;
  static const ENTER_KEY = 13;
  static const ESCAPE_KEY = 27;

  SparkWidget.created() : super.created();

  // TODO(ussuri): Temporarily leave for experiments. Remove soon: unsupported
  // at least from Chrome M34.
  @deprecated
  @override
  bool get applyAuthorStyles => false;

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

  List<Node> getExpandedDistributedNodes(String contentSelector) {
    final ContentElement content = shadowRoot.querySelector(contentSelector);
    return expandCascadingContents(content);
  }

  static List<Node> expandCascadingContents(ContentElement content) {
    return content
        .getDistributedNodes()
        .expand((e) => e is ContentElement ? expandCascadingContents(e) : [e])
        .toList(growable: true);
  }
}
