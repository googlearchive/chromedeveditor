// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'package:chrome_testing/testing_app.dart';

import 'tests/server_test.dart' as server_test;
import 'tests/tcp_test.dart' as tcp_test;

void main() {
  TestDriver testDriver = new TestDriver(
      defineTests, connectToTestListener: true);
}

void defineTests() {
  server_test.defineTests();
  tcp_test.defineTests();
}
