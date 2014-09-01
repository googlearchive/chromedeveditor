// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'adaptable_test.dart' as adaptable_test;
import 'dependencies_test.dart' as dependencies_test;
import 'event_bus_test.dart' as event_bus_test;

void main() {
  adaptable_test.defineTests();
  dependencies_test.defineTests();
  event_bus_test.defineTests();
}
