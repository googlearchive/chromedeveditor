// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.exception;

/**
 * A wrapper class for all errors thrown by git. Each error is represented
 * by a unique [errorCode] pre-defined by GitErrorConstants class.
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
 * Defines all error types in git as string. Each error string represents
 * a unique GitError.
 */
class GitErrorConstants {
  static final String GIT_BRANCH_NOT_FOUND
     = "git.branch_not_found";

  static final String GIT_CLONE_GIT_DIR_IN_USE
     = "git.clone_dir_in_use";

  static final String GIT_PUSH_NO_REMOTE
      = "git.push_no_remote";

  static final String GIT_PUSH_NO_COMMITS
      = "git.push_no_commits";

  static final String GIT_OBJECT_STORE_CORRUPTED
      = "git.object_store_corrupted";

  static final String GIT_COMMIT_NO_CHANGES
      = "git.commit_no_changes";

  static final String GIT_AUTH_FAILURE
      = "git.auth_failure";

  static final String GIT_REPO_NOT_FOUND
      = "git.repo_not_found";
}
