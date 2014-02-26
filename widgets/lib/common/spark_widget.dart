// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets;

import 'dart:async' show Timer;
import 'dart:html' show Node, Element, ContentElement;

import 'package:polymer/polymer.dart';

const bool IS_DART2JS = identical(1, 1.0);

// NOTE: This SparkWidget element is not intended to use directly.
@CustomTag('spark-widget')
class SparkWidget extends PolymerElement {
  static const CSS_ENABLED = "enabled";
  static const CSS_DISABLED = "disabled";

  SparkWidget.created() : super.created();

  String joinClasses(List<String> cls) => cls.join(" ");

  Element getShadowDomElement(String selectors) =>
      shadowRoot.querySelector(selectors);

  @override
  void focus() {
    super.focus();

    // Only the first found element that has 'focused' attribute on it will be
    // actually focused; if there are more than one, the rest will be ignored.
    Element elementToFocus = getShadowDomElement('[focused]');
    if (elementToFocus != null) {
      elementToFocus.focus();
    }
  }

  /**
   * Certain kinds of elements, e.g. <div>, by default do not accept keyboard
   * events. Assinging tabIndex to them makes them keyboard-focusable, and
   * therefore accepting keyboard events.
   */
  void enableKeyboardEvents() {
    if (tabIndex == null) {
      tabIndex = 0;
    }
  }

  void veil() {
    classes..remove('unveiled')..add('veiled');
  }

  void unveil() {
    classes..remove('veiled')..add('unveiled');
  }

  /**
   * Prevent FOUC (Flash Of Unstyled Content).
   */
  void preventFlashOfUnstyledContent(int msec) {
    // TODO(ussuri): We use a temporary crude way here. Polymer's avertised
    // machanisms (via :resolved pseudo class as well as older .polymer-veiled
    // class) have failed to work so far, although :unresolved reportedly
    // functions in Chrome 34. Revisit.
    veil();
    new Timer(new Duration(milliseconds: msec), unveil);
  }

  /**
   * Find a <content> element using a CSS selector and expand it, and any
   * recursively nested <content> elements distributed from light DOM as a result
   * of multi-level element embedding, with their children.
   */
  Iterable<Node> getExpandedDistributedNodes(String contentSelector) {
    final ContentElement content = shadowRoot.querySelector(contentSelector);
    return inlineNestedContentNodes(content);
  }

  /**
   * Inline a given <content> element, and any recursively nested <content> elements
   * distributed from light DOM as a result of multi-level element embedding, with
   * their children.
   */
  static Iterable<Node> inlineNestedContentNodes(ContentElement content) {
    final List<Node> dn = content.getDistributedNodes();
    final Iterable<Node> fdn = dn.where(
        (Element e) => e.localName != "template");
    final Iterable<Node> edn = fdn.expand(
        (Element e) => e is ContentElement ?
            inlineNestedContentNodes(e) : [e]);
    return edn;
  }
}
