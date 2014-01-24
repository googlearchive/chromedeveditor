// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'package:grinder/grinder.dart' as grinder;

import 'tool/grind.dart' as grind;

void main() {
  new grinder.Grinder()
    ..addTask(new grinder.GrinderTask(
        'update', taskFunction: grind.setup))
    ..addTask(new grinder.GrinderTask(
        'lint', taskFunction: grind.lint, depends: ['update']))
    ..start(['lint']);
}
