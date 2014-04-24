// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.exception;

/**
 * A wrapper class for all errors thrown inside spark. Each error is represented
 * by a unique [errorCode] pre-defined by SparkErrorConstants class.
 */
class SparkException implements Exception {
  /// Represents the unique string for each error type.
  final String errorCode;
  final String message;

  /// Indicates if the error is not necessary to be handled and can be ignored.
  bool canIgnore = false;

  SparkException([this.errorCode, this.message, this.canIgnore]);

  String toString() => message == null ? "SparkException($errorCode)"
      : "SparkException($errorCode) : $message";
}

/**
 * Defines all error types in spark as string. Each error string represents
 * a unique [SparkException].
 */
class SparkErrorConstants {
  static final String GIT_BRANCH_NOT_FOUND = "git.branch_not_found";
  static final String GIT_CLONE_GIT_DIR_IN_USE = "git.clone_dir_in_use";
}
