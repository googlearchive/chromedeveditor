// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.button;

import 'dart:html';

import 'package:polymer/polymer.dart';

import '../common/widget.dart';

@CustomTag('spark-button')
class SparkButton extends Widget {
  @published bool primary = false;

  // TODO: changing this field does not cause the btnClasses to be re-calculated
  bool _active = true;
  @published bool get active => _active;
  set active(bool value) {
    _active = value;
    getShadowDomElement('button').className = btnClasses;
  }

  @published bool large = false;
  @published bool small = false;

  String get actionId => attributes['action-id'];

  @observable String get btnClasses {
    List classes = [
        CSS_BUTTON,
        primary ? CSS_PRIMARY : CSS_DEFAULT,
        active ? Widget.CSS_ENABLED : Widget.CSS_DISABLED
    ];

    if (large) classes.add(CSS_LARGE);
    if (small) classes.add(CSS_SMALL);

    return joinClasses(classes);
  }

  static const CSS_BUTTON = "btn";
  static const CSS_DEFAULT = "btn-default";
  static const CSS_PRIMARY = "btn-primary";
  static const CSS_LARGE = "btn-lg";
  static const CSS_SMALL = "btn-sm";

  SparkButton.created() : super.created();

  void focus() {
    // Only the first found element that has 'focused' attribute on it will be
    // actually focused; if there are more than one, the rest will be ignored.
    Element elementToFocus = this.getShadowDomElement('[focused]');
    if (elementToFocus != null) {
      elementToFocus.focus();
    }
  }
}
