// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:html';

import 'package:polymer/polymer.dart';

/**
 * A Polymer cde-extension-point element.
 *
 * TODO: doc this
 */
@CustomTag('cde-extension-point')
class CdeExtensionPoint extends PolymerElement {
  /// Called when an instance of cde-extension-point is inserted into the DOM.
  void attached() {
    super.attached();
    //print('ready ${this} ($id)');
    //print(findMatching(document.querySelectorAll('cde-extensions')));
  }

  /// Called when cde-extension-point has been fully prepared (Shadow DOM
  /// created, property observers set up, event listeners attached).
  void ready() {
    print('ready ${this} ($id)');
    Iterable<Element> extensions = findMatching(
        document.querySelectorAll('cde-extensions'));

    for (Element ext in extensions) {
      children.add(ext.clone(true));
    }
  }

  Iterable findMatching(Iterable<Element> itor) {
    // TODO: Warn about nodes that do not have `extension=xxx`.
    return itor.expand((Element e) => e.children).where((Element e) {
      print(e);
      return e.attributes['extension'] == id;
    });
  }

  CdeExtensionPoint.created() : super.created();
}
