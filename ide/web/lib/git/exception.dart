// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.exception;

/**
 * A wrapper class for all errors thrown by git. Each error is represented by a
 * unique [errorCode] pre-defined by the [GitErrorConstants] class.
 */
class GitException implements Exception {
  /// Represents the unique string for each error type.
  final String errorCode;
  final String message;

  /// Indicates if the error is not necessary to be handled and can be ignored.
  final bool canIgnore;

  GitException([this.errorCode, this.message, this.canIgnore = false]);

  String toString() => message == null ? "GitException: $errorCode"
      : "GitException: $message ($errorCode)";
}

/**
 * Defines all error types in git as string. Each error string represents a
 * unique [GitException].
 */
class GitErrorConstants {

  static const String GIT_HTTP_NOT_FOUND_ERROR = "git.http_not_found_error";
  static const String GIT_HTTP_FORBIDDEN_ERROR = "git.http_forbidden_error";
  static const String GIT_HTTP_ERROR = "git.http_error";
  static const String GIT_AUTH_REQUIRED = "git.auth_required";
  static const String GIT_HTTP_CONN_RESET = "git.http_conn_reset";
  static const String GIT_AUTH_ERROR = "git.auth_error";

  static const String GIT_CLONE_DIR_NOT_EMPTY = "git.clone_dir_not_empty";
  static const String GIT_CLONE_DIR_IN_USE = "git.clone_dir_in_use";
  static const String GIT_CLONE_DIR_NOT_INITIALIZED =
      "git.clone_dir_not_initialized";
  static const String GIT_CLONE_CANCEL = "git.clone_cancel";

  static const String GIT_BRANCH_UP_TO_DATE = "git.branch_up_to_date";
  static const String GIT_BRANCH_NOT_FOUND = "git.branch_not_found";
  static const String GIT_REMOTE_BRANCH_NOT_FOUND =
      "git.remote_branch_not_found";
  static const String GIT_BRANCH_EXISTS = "git.branch_exists";
  static const String GIT_INVALID_BRANCH_NAME = "git.invalid_branch_name";

  static const String GIT_PUSH_NO_REMOTE = "git.push_no_remote";
  static const String GIT_PUSH_NO_COMMITS = "git.push_no_commits";
  static const String GIT_PUSH_NON_FAST_FORWARD = "git.push_non_fast_forward";

  static const String GIT_PULL_NON_FAST_FORWARD = "git.pull_non_fast_forward";

  static const String GIT_OBJECT_STORE_CORRUPTED = "git.object_store_corrupted";

  static const String GIT_COMMIT_NO_CHANGES = "git.commit_no_changes";

  static const String GIT_FETCH_UP_TO_DATE = "git.fetch_up_to_date";

  static const String GIT_MERGE_ERROR = "git.merge_error";

  static const String GIT_INVALID_REPO_URL = "git.invalid_repo_url";
  static const String GIT_WORKING_TREE_NOT_CLEAN = "git.working_tree_not_clean";
  static const String GIT_FILE_STATUS_TYPE_UNKNOWN =
      "git.file_status_type_unknown";
  static const String GIT_SUBMODULES_NOT_YET_SUPPORTED =
      "git.submodules_not_yet_supported";
}
