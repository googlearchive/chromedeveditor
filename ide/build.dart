// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'package:grinder/grinder.dart' as grind;
import 'package:polymer/builder.dart' as polymer;

import 'tool/grind.dart' as grind;

void main() {
  new grind.Grinder()
    ..addTask(new grind.GrinderTask(
        'update', taskFunction: update))
    ..addTask(new grind.GrinderTask(
        'lint', taskFunction: lint, depends: ['update']))
    ..start(['lint']);
}

void update(context) {
  grind.setup(context);
}

void lint(context) {
  polymer.lint(entryPoints: ['app/spark_polymer.html']);
}
