// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.button;

//import 'dart:async' as async;

import 'package:polymer/polymer.dart';

import '../common/spark_widget.dart';

@CustomTag('spark-button')
class SparkButton extends SparkWidget {
  @published
  bool primary = false;
  @published
  bool active = true;
  @published
  bool large = false;
  @published
  bool small = false;
  @published
  bool noPadding = false;

  String get actionId => attributes['action-id'];

  @observable
  final btnClasses = toObservable({
    CSS_BUTTON: true
  });

  @override
  void enteredView() {
    super.enteredView();
    updateBtnClassesJob();
  }

  void updateBtnClasses() {
    btnClasses[CSS_PRIMARY] = primary;
    btnClasses[CSS_DEFAULT] = !primary;
    btnClasses[SparkWidget.CSS_ENABLED] = active;
    btnClasses[SparkWidget.CSS_DISABLED] = !active;
    btnClasses[CSS_LARGE] = large;
    btnClasses[CSS_SMALL] = small;
  }

  /**
   * only modify collection once for several succinct events
   */
  var btnClassesJob = false;
  void updateBtnClassesJob() {
    // see https://code.google.com/p/dart/issues/detail?id=17859
    updateBtnClasses();
//    if (btnClassesJob == false) {
//      btnClassesJob = true;
//      async.scheduleMicrotask(() {
//        updateBtnClasses();
//        btnClassesJob = false;
//      });
//    }
  }

  void activeChanged(old) {
    updateBtnClassesJob();
  }

  void primaryChanged(old) {
    updateBtnClassesJob();
  }

  void largeChanged(old) {
    updateBtnClassesJob();

    // TODO should this disable small?
  }

  void smallChanged(old) {
    updateBtnClassesJob();

    // TODO should this disable large?
  }

  static const CSS_BUTTON = "btn";
  static const CSS_DEFAULT = "btn-default";
  static const CSS_PRIMARY = "btn-primary";
  static const CSS_LARGE = "btn-lg";
  static const CSS_SMALL = "btn-sm";

  SparkButton.created(): super.created();
}
