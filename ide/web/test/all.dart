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
import 'app_manifest_validator_test.dart' as app_manifest_validator_test;
import 'app_test.dart' as app_test;
import 'benchmarks.dart' as benchmarks;
import 'builder_test.dart' as builder_test;
import 'dependency_test.dart' as dependency_test;
import 'cssbeautify_test.dart' as cssbeautify_test;
import 'editors_test.dart' as editors_test;
import 'event_bus_test.dart' as event_bus_test;
import 'files_test.dart' as files_test;
import 'jobs_test.dart' as jobs_test;
import 'jshint_test.dart' as jshint_test;
import 'json_parser_test.dart' as json_parser_test;
import 'json_validator_test.dart' as json_validator_test;
import 'git/all.dart' as git_all_test;
import 'navigation_test.dart' as navigation_test;
import 'outline_test.dart' as outline_test;
import 'preferences_test.dart' as preferences_test;
import 'editor_config_test.dart' as editor_config_test;
import 'pub_test.dart' as pub_test;
import 'scm_test.dart' as scm_test;
import 'sdk_test.dart' as sdk_test;
import 'search_test.dart' as search_test;
import 'services_test.dart' as services_test;
import 'services_common_test.dart' as services_common_test;
import 'ui/all.dart' as ui_all_test;
import 'utils_test.dart' as utils_test;
import 'workspace_test.dart' as workspace_test;

/**
 * Place all new tests here.
 */
void defineTests() {
  ace_test.defineTests();
  actions_test.defineTests();
  analytics_test.defineTests();
  app_manifest_validator_test.defineTests();
  app_test.defineTests();
  builder_test.defineTests();
  dependency_test.defineTests();
  cssbeautify_test.defineTests();
  editors_test.defineTests();
  event_bus_test.defineTests();
  files_test.defineTests();
  jobs_test.defineTests();
  jshint_test.defineTests();
  json_parser_test.defineTests();
  json_validator_test.defineTests();
  git_all_test.defineTests();
  navigation_test.defineTests();
  outline_test.defineTests();
  preferences_test.defineTests();
  editor_config_test.defineTests();
  pub_test.defineTests();
  scm_test.defineTests();
  sdk_test.defineTests();
  search_test.defineTests();
  services_test.defineTests();
  services_common_test.defineTests();
  ui_all_test.defineTests();
  utils_test.defineTests();
  workspace_test.defineTests();

  // Run our benchmarks as well.
  benchmarks.defineTests();
}
