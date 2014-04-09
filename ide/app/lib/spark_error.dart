// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.error;

/**
 * A wrapper class for all errors thrown inside spark. Each error is represented
 * by a unique [errorString] pre-defined in spark_error_constants.dart.
 */
class SparkError extends Error {
  // Represents the unique string for each error type.
  final String errorString;
  final String message;

  // Indicates if the error is not necessary to be handled and can be ignored.
  bool canIgnore = false;

  SparkError([this.errorString, this.message, this.canIgnore]);

  String toString() {
    if (message != null) {
      return "SparkError($errorString) : $message";
    }
    return "SparkError($errorString)";
  }
}
