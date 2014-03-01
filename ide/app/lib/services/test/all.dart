// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This library defines all tests for Spark.
 */
library spark.all_tests;

import 'analyzer_test.dart' as analyzer_test;
import '../../services/services_impl.dart';

/**
 * Place all new tests here.
 */
void defineTests(ServicesIsolate servicesIsolate) {
  analyzer_test.defineTests(servicesIsolate);
}
