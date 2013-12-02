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
import 'editors_test.dart' as editors_test;
import 'files_test.dart' as files_test;
import 'git/file_operations_test.dart' as git_file_operations_test;
import 'git/git_test.dart' as git_test;
import 'git/object_test.dart' as git_object_test;
import 'git/objectstore_test.dart' as git_objectstore_test;
import 'git/pack_test.dart' as git_pack_test;
import 'git/pack_index_test.dart' as git_pack_index_test;
import 'git/zlib_test.dart' as zlib_test;
import 'git/utils_test.dart' as git_utils_test;
import 'preferences_test.dart' as preferences_test;
import 'sdk_test.dart' as sdk_test;
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
  compiler_test.defineTests();
  editors_test.defineTests();
  files_test.defineTests();
  git_file_operations_test.defineTests();
  git_object_test.defineTests();
  git_objectstore_test.defineTests();
  git_pack_test.defineTests();
  git_pack_index_test.defineTests();
  git_test.defineTests();
  git_utils_test.defineTests();
  preferences_test.defineTests();
  sdk_test.defineTests();
  server_test.defineTests();
  tcp_test.defineTests();
  utils_test.defineTests();
  workspace_test.defineTests();
  zlib_test.defineTests();
}
