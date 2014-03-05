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

  SparkWidget.created() : super.created();

  String joinClasses(List<String> cls) => cls.join(" ");

  Element getShadowDomElement(String selectors) =>
      shadowRoot.querySelector(selectors);

  @override
  void focus() {
    super.focus();
    _applyAutofocus(true);
  }

  @override
  void blur() {
    super.blur();
    _applyAutofocus(false);
  }

  /**
   * Look for an element with an `autofocus` attribute in our light DOM and
   * shadow DOM, giving priority to the former, and if found, focus the element.
   */
  void _applyAutofocus(bool isFocused) {
    //
    ElementList elts = this.querySelectorAll('[autofocus]');
    if (elts.isEmpty) {
      elts = shadowRoot.querySelectorAll('[autofocus]');
    }
    if (elts.isNotEmpty) {
      // At most one element is expected to have an `autofocus` attribute.
      // Use [first] vs [single] to be more lax to errors in production.
      assert(elts.length == 1);
      isFocused ? elts.first.focus() : elts.first.blur();
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
    classes..remove('unveiled')..toggle('veiled', true);
  }

  void unveil() {
    classes..remove('veiled')..toggle('unveiled', true);
  }

  /**
   * Prevent FOUC (Flash Of Unstyled Content).
   */
  void preventFlashOfUnstyledContent({Function method,
                                      Duration delay}) {
    // TODO(ussuri): We use a temporary crude way here. Polymer's advertised
    // machanisms (via :resolved pseudo class as well as older .polymer-veiled
    // class) have failed to work so far, although :unresolved reportedly
    // functions in Chrome 34. Revisit.
    veil();

    if (method != null) {
      method();
    }

    if (delay != null) {
      asyncTimer(unveil, delay);
    } else {
      unveil();
    }
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
        (Node e) => (e is Element) && e.localName != "template");
    final Iterable<Node> edn = fdn.expand(
        (Node e) => e is ContentElement ?
            inlineNestedContentNodes(e) : [e]);
    return edn;
  }
}
