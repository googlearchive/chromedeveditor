// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This library defines all tests for Spark.
 */
library spark.all_tests;

import 'ace_test.dart' as ace_test;
import 'actions_test.dart' as actions_test;
import 'analytics_test.dart' as analytics_test;
import 'analyzer_test.dart' as analyzer_test;
import 'app_test.dart' as app_test;
import 'builder_test.dart' as builder_test;
import 'compiler_test.dart' as compiler_test;
import 'editors_test.dart' as editors_test;
import 'event_bus_test.dart' as event_bus_test;
import 'files_test.dart' as files_test;
import 'jobs_test.dart' as jobs_test;
import 'git/all.dart' as git_all_test;
import 'preferences_test.dart' as preferences_test;
import 'scm_test.dart' as scm_test;
import 'sdk_test.dart' as sdk_test;
import 'search_test.dart' as search_test;
import 'server_test.dart' as server_test;
import 'tcp_test.dart' as tcp_test;
import 'utils_test.dart' as utils_test;
import 'workspace_test.dart' as workspace_test;

/**
 * Place all new tests here.
 */
void defineTests() {
  ace_test.defineTests();
  actions_test.defineTests();
  analytics_test.defineTests();
  analyzer_test.defineTests();
  app_test.defineTests();
  builder_test.defineTests();
  compiler_test.defineTests();
  editors_test.defineTests();
  event_bus_test.defineTests();
  files_test.defineTests();
  jobs_test.defineTests();
  git_all_test.defineTests();
  preferences_test.defineTests();
  scm_test.defineTests();
  sdk_test.defineTests();
  search_test.defineTests();
  server_test.defineTests();
  tcp_test.defineTests();
  utils_test.defineTests();
  workspace_test.defineTests();
}
