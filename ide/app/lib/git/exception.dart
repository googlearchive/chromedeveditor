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
  bool canIgnore = false;

  GitException([this.errorCode, this.message, this.canIgnore]);

  String toString() => message == null ? "GitException($errorCode)"
      : "GitException($errorCode) : $message";
}

/**
 * Defines all error types in git as string. Each error string represents a
 * unique [GitException].
 */
class GitErrorConstants {


  static final String GIT_CLONE_DIR_NOT_EMPTY = "git.clone_dir_not_empty";
  static final String GIT_CLONE_DIR_IN_USE = "git.clone_dir_in_use";
  static final String GIT_CLONE_DIR_NOT_INITIALIZED
      = "git.clone_dir_not_initialized";
  static final String GIT_CLONE_CANCEL = "git.clone_cancel";
  static final String GIT_AUTH_ERROR = "git.auth_error";
  static final String GIT_HTTP_ERROR = "git.http_error";
  static final String GIT_BRANCH_NOT_FOUND = "git.branch_not_found";
  static final String GIT_PUSH_NO_REMOTE = "git.push_no_remote";
  static final String GIT_PUSH_NO_COMMITS = "git.push_no_commits";
  static final String GIT_OBJECT_STORE_CORRUPTED = "git.object_store_corrupted";
  static final String GIT_COMMIT_NO_CHANGES = "git.commit_no_changes";
  static final String GIT_AUTH_REQUIRED = "git.auth_required";
  static final String GIT_HTTP_404_ERROR = "git.http_404_error";
  static final String GIT_INVALID_REPO_URL = "git.invalid_repo_url";
  static final String GIT_SUBMODULES_NOT_YET_SUPPORTED
      = "git.submodules_not_yet_supported";
}
