// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.exception;

import 'git/exception.dart';

/**
 * A wrapper class for all errors thrown inside spark. Each error is represented
 * by a unique [errorCode] pre-defined by SparkErrorConstants class.
 */
class SparkException implements Exception {
  /// The error message.
  final String message;
  /// Represents the unique string for each error type.
  final String errorCode;
  /// Indicates if the error is not necessary to be handled and can be ignored.
  final bool canIgnore;
  /// Indicates whether the exception is an error or a status.
  final bool isError;
  /// Original exception.
  dynamic exception;

  SparkException(this.message, {this.errorCode, this.exception,
    this.canIgnore: false, this.isError: true});

  static SparkException fromException(dynamic e) {
    if (e is SparkException) {
      return e;
    } else if (e is GitException) {
      return _fromGitException(e);
    } else if (e != null) {
      return new SparkException(e.toString());
    } else {
      return new SparkException("Unknown error");
    }
  }

  static SparkException _fromGitException(GitException e) {
    switch (e.errorCode) {
      case GitErrorConstants.GIT_AUTH_REQUIRED:
        return new SparkException(
            e.toString(), errorCode: SparkErrorConstants.GIT_AUTH_REQUIRED);

      case GitErrorConstants.GIT_HTTP_FORBIDDEN_ERROR:
        return new SparkException(
            e.toString(), errorCode: SparkErrorConstants.GIT_HTTP_FORBIDDEN_ERROR);

      case GitErrorConstants.GIT_CLONE_CANCEL:
        return new SparkException(
            e.toString(),
            errorCode: SparkErrorConstants.GIT_CLONE_CANCEL,
            canIgnore: true);

      case GitErrorConstants.GIT_SUBMODULES_NOT_YET_SUPPORTED:
        return new SparkException(
            SparkErrorMessages.GIT_SUBMODULES_NOT_YET_SUPPORTED_MSG,
            errorCode: SparkErrorConstants.GIT_SUBMODULES_NOT_YET_SUPPORTED);

      case GitErrorConstants.GIT_PUSH_NON_FAST_FORWARD:
        return new SparkException(SparkErrorMessages.GIT_PUSH_NON_FAST_FORWARD_MSG,
            errorCode: SparkErrorConstants.GIT_PUSH_NON_FAST_FORWARD);

      case GitErrorConstants.GIT_PUSH_NO_REMOTE:
        return new SparkException(SparkErrorMessages.GIT_PUSH_NO_REMOTE_MSG,
            errorCode: SparkErrorConstants.GIT_PUSH_NO_REMOTE);

      case GitErrorConstants.GIT_PUSH_NO_COMMITS:
        return new SparkException(SparkErrorMessages.GIT_PUSH_NO_COMMITS_MSG,
            errorCode: SparkErrorConstants.GIT_PUSH_NO_COMMITS);

      case GitErrorConstants.GIT_BRANCH_EXISTS:
        return new SparkException(SparkErrorMessages.GIT_BRANCH_EXISTS_MSG,
            errorCode: SparkErrorConstants.GIT_BRANCH_EXISTS);

      case GitErrorConstants.GIT_BRANCH_NOT_FOUND:
        return new SparkException(SparkErrorMessages.GIT_BRANCH_NOT_FOUND_MSG,
            errorCode: SparkErrorConstants.GIT_BRANCH_NOT_FOUND);

      case GitErrorConstants.GIT_BRANCH_UP_TO_DATE:
        return new SparkException(SparkErrorMessages.GIT_BRANCH_UP_TO_DATE_MSG,
            errorCode: SparkErrorConstants.GIT_BRANCH_UP_TO_DATE);

      case GitErrorConstants.GIT_INVALID_BRANCH_NAME:
        return new SparkException(SparkErrorMessages.GIT_INVALID_BRANCH_NAME_MSG,
            errorCode: SparkErrorConstants.GIT_INVALID_BRANCH_NAME);

      case GitErrorConstants.GIT_REMOTE_BRANCH_NOT_FOUND:
        return new SparkException(SparkErrorMessages.GIT_REMOTE_BRANCH_NOT_FOUND_MSG,
            errorCode: SparkErrorConstants.GIT_REMOTE_BRANCH_NOT_FOUND);

      case GitErrorConstants.GIT_BRANCH_UP_TO_DATE:
        return new SparkException(SparkErrorMessages.GIT_BRANCH_UP_TO_DATE_MSG,
            errorCode: SparkErrorConstants.GIT_BRANCH_UP_TO_DATE);

      case GitErrorConstants.GIT_WORKING_TREE_NOT_CLEAN:
        return new SparkException(SparkErrorMessages.GIT_WORKING_TREE_NOT_CLEAN_MSG,
            errorCode: SparkErrorConstants.GIT_WORKING_TREE_NOT_CLEAN);

      case GitErrorConstants.GIT_HTTP_CONN_RESET:
        return new SparkException(SparkErrorMessages.GIT_HTTP_CONN_RESET_MSG,
            errorCode: SparkErrorConstants.GIT_HTTP_CONN_RESET);

      case GitErrorConstants.GIT_INVALID_REPO_URL:
        return new SparkException(SparkErrorMessages.GIT_INVALID_REPO_URL_MSG,
            errorCode: SparkErrorConstants.GIT_INVALID_REPO_URL);

      case GitErrorConstants.GIT_PULL_NON_FAST_FORWARD:
        return new SparkException(SparkErrorMessages.GIT_PULL_NON_FAST_FORWARD_MSG,
            errorCode: SparkErrorConstants.GIT_PULL_NON_FAST_FORWARD);
    }

    return new SparkException(e.toString());
  }

  String toString() => errorCode == null ?
      "SparkException: $message" : "SparkException: $message ($errorCode)";
}

/**
 * Defines all error types in spark as string. Each error string represents a
 * unique [SparkException].
 */
class SparkErrorConstants {
  static const String GIT_CLONE_DIR_IN_USE = "git.clone_dir_in_use";
  static const String GIT_CLONE_CANCEL = "git.clone_cancel";

  static const String GIT_AUTH_REQUIRED = "git.auth_required";
  static const String GIT_HTTP_FORBIDDEN_ERROR = "git.http_forbidden_error";
  static const String GIT_HTTP_CONN_RESET = "git.http_conn_reset";
  static const String GIT_INVALID_REPO_URL = "git.invalid_repo_url";

  static const String GIT_PUSH_NON_FAST_FORWARD =
      "git.push_non_fast_forward";
  static const String GIT_PUSH_NO_REMOTE = "git.push_no_remote";
  static const String GIT_PUSH_NO_COMMITS = "git.push_no_commits";

  static const String GIT_PULL_NON_FAST_FORWARD = "git.pull_non_fast_farward";

  static const String GIT_BRANCH_EXISTS = 'git.branch_exists';
  static const String GIT_BRANCH_UP_TO_DATE = "git.branch_up_to_date";
  static const String GIT_BRANCH_NOT_FOUND = "git.branch_not_found";
  static const String GIT_REMOTE_BRANCH_NOT_FOUND =
      "git.remote_branch_not_found";
  static const String GIT_INVALID_BRANCH_NAME = "git.invalid_branch_name";

  static const String GIT_WORKING_TREE_NOT_CLEAN = "git.working_tree_not_clean";
  static const String GIT_SUBMODULES_NOT_YET_SUPPORTED =
      "git.submodules_not_yet_supported";

  static const String RUN_APP_NOT_FOUND_IN_CHROME =
      "run.app_not_found_in_chrome";
  static const String PUB_ON_WINDOWS_NOT_SUPPORTED =
      "pub.windows_not_supported";
  static const String SYMLINKS_OPERATION_NOT_SUPPORTED =
      "symlinks_not_supported";

}

class SparkErrorMessages {
  static const String GIT_PUSH_NON_FAST_FORWARD_MSG
      = 'Non fast-forward push is not yet supported.';
  static const String GIT_PUSH_NO_REMOTE_MSG = "No remote to push.";
  static const String GIT_PUSH_NO_COMMITS_MSG = "No commits to push.";

  static const String GIT_BRANCH_EXISTS_MSG = "Branch already exists.";
  static const String GIT_BRANCH_UP_TO_DATE_MSG = "Branch up to date.";
  static const String GIT_BRANCH_NOT_FOUND_MSG = "Branch not found.";
  static const String GIT_REMOTE_BRANCH_NOT_FOUND_MSG =
      "remote branch not found.";
  static const String GIT_INVALID_BRANCH_NAME_MSG = "Invalid branch name.";

  static const String GIT_WORKING_TREE_NOT_CLEAN_MSG = "Working tree is not clean.";
  static const String GIT_SUBMODULES_NOT_YET_SUPPORTED_MSG =
      "Repositories with sub modules are not yet supported.";
  static const String GIT_HTTP_CONN_RESET_MSG  = "The connection was reset by "
      "the server. This may happen when pushing commits with large changes.";
  static const String GIT_INVALID_REPO_URL_MSG  = "Received an error from the server;"
      " possibly an invalid repo URL?";

  static const String GIT_PULL_NON_FAST_FORWARD_MSG =
      "Merge conflicts detected. Chrome Dev Editor does not currently support "
      "non-fast forward pulls. As a work-around you can merge your changes on "
      "the remote server and pull those merged changes in.";

  static const String RUN_APP_NOT_FOUND_IN_CHROME_MSG =
      "Failed to install the application into Chrome; please check Chrome for "
      "a possible error dialog.";

  static const String PUB_ON_WINDOWS_MSG =
      "Running 'pub get' and 'pub upgrade' is currently not supported on "
      "Windows, however you can use the pub command line tool to get the "
      "packages.\nYou can track the issue at: "
      "https://github.com/dart-lang/chromedeveditor/issues/2862.";

  static const String SYMLINKS_ERROR_MSG =
      "Operations on directories containing symlinks are not supported. Delete "
      "directories containing symlinks using other tools and try again.";
}
