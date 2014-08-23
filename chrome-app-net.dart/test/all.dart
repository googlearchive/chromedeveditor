// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library all_tests;

import 'tests/server_test.dart' as server_test;
import 'tests/tcp_test.dart' as tcp_test;

// TODO: get these tests running

// TODO: add a chrome app test app here

/**
 * Place all new tests here.
 */
void defineTests() {
  server_test.defineTests();
  tcp_test.defineTests();
}
