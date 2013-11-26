// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.button;

import 'dart:html';

import 'package:polymer/polymer.dart';

import '../src/widget.dart';

@CustomTag('spark-button')
class SparkButton extends Widget {
  @published bool primary = false;
  @published bool active = false;
  @observable String get btnClasses =>
      "$_C_BUTTON ${primary ? _C_PRIMARY : _C_DEFAULT}";

  static const _C_BUTTON = "btn";
  static const _C_DEFAULT = "btn-default";
  static const _C_PRIMARY = "btn-primary";

  SparkButton.created() : super.created();
}
