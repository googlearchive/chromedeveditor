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
import 'compiler_test.dart' as compiler_test;
import 'files_test.dart' as files_test;
import 'git_object_test.dart' as git_object_test;
import 'git_pack_test.dart' as git_pack_test;
import 'git_pack_index_test.dart' as git_pack_index_test;
import 'git_test.dart' as git_test;
import 'preferences_test.dart' as preferences_test;
import 'sdk_test.dart' as sdk_test;
import 'server_test.dart' as server_test;
import 'tcp_test.dart' as tcp_test;
import 'utils_test.dart' as utils_test;
import 'workspace_test.dart' as workspace_test;
import 'zlib_test.dart' as zlib_test;

/**
 * Place all new tests here.
 */
void defineTests() {
  ace_test.main();
  actions_test.main();
  analytics_test.main();
  analyzer_test.main();
  app_test.main();
  compiler_test.main();
  files_test.main();
  git_object_test.main();
  git_pack_test.main();
  git_pack_index_test.main();
  git_test.main();
  preferences_test.main();
  sdk_test.main();
  server_test.main();
  tcp_test.main();
  utils_test.main();
  workspace_test.main();
  zlib_test.main();
}
