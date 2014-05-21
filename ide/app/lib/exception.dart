// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.exception;

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
  bool canIgnore = false;

  SparkException(this.message, [this.errorCode, this.canIgnore]);

  String toString() => errorCode == null ?
      "SparkException: $message" : "SparkException($errorCode): $message";
}

/**
 * Defines all error types in spark as string. Each error string represents a
 * unique [SparkException].
 */
class SparkErrorConstants {
  static final String BRANCH_NOT_FOUND = "branch_not_found";
  static final String CLONE_GIT_DIR_IN_USE = "clone_dir_in_use";
  static final String AUTH_REQUIRED = "auth.required";
  static final String GIT_SUBMODULES_NOT_YET_SUPPORTED
      = "git.submodules_not_yet_supported";
}
