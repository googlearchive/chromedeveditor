// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This test runner is used to drive Dart Chrome App unit tests in an automated
 * fashion. The general flow is:
 *
 * - start a test listener
 * - start Chrome with --load-and-launch-app=spark/app
 * - handle test output, check for test timeout
 * - kill process
 * - report back with test results and exit code
 */
library chrome_testing.runner;

import 'package:chrome_testing/testing_cli.dart' as testing;

void main([List<String> args = const []]) {
  testing.performTesting(args);
}
