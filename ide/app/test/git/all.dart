// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.git.all_tests;

import 'commands/branch_test.dart' as git_commands_branch_test;
import 'commands/checkout_test.dart' as git_commands_checkout_test;
import 'commands/clone_test.dart' as git_commands_clone_test;
import 'commands/commit_test.dart' as git_commands_commit_test;
import 'commands/conditions_test.dart' as git_commands_conditions_test;
import 'commands/merge_test.dart' as git_commands_merge_test;
import 'commands/pull_test.dart' as git_commands_pull_test;
import 'commands/push_test.dart' as git_commands_push_test;
import 'file_operations_test.dart' as git_file_operations_test;
import 'object_test.dart' as git_object_test;
import 'objectstore_test.dart' as git_objectstore_test;
import 'pack_test.dart' as git_pack_test;
import 'pack_index_test.dart' as git_pack_index_test;
import 'zlib_test.dart' as zlib_test;
import 'utils_test.dart' as git_utils_test;

/**
 * Place all new tests here.
 */
void defineTests() {
  git_commands_branch_test.defineTests();
  git_commands_checkout_test.defineTests();
  git_commands_commit_test.defineTests();
  git_commands_clone_test.defineTests();
  git_commands_conditions_test.defineTests();
  git_commands_merge_test.defineTests();
  git_commands_pull_test.defineTests();
  git_commands_push_test.defineTests();
  git_file_operations_test.defineTests();
  git_object_test.defineTests();
  git_objectstore_test.defineTests();
  git_pack_test.defineTests();
  git_pack_index_test.defineTests();
  git_utils_test.defineTests();
  zlib_test.defineTests();
}
