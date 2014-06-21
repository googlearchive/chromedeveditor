// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.status;

import 'exception.dart';

class SparkJobStatus {
  String _message;
  String header;
  String statusCode = SparkStatusCodes.SPARK_JOB_STATUS_UNKNOWN;

  /// Indicates whether the job was successful or failed.
  bool success = true;

  /// The underlining exception object in case the job failed.
  SparkException exception;

  get message => _message;

  set message(String msg) => _message = msg;

  SparkJobStatus([this.statusCode, this.header, this._message]) {
    if (_message == null) {
      try {
        _message = getStatusMessageFromCode(this.statusCode);
      } catch (e) {
        // Do Nothing.
      }
    }
  }

  static String getStatusMessageFromCode(String code) {
    switch (code) {
      case SparkStatusCodes.SPARK_JOB_BUILD_SUCCESS:
        return SparkStatusMessages.SPARK_JOB_BUILD_SUCCESS_MSG;
    }
    throw "Message for code : ${code} not found.";
  }
}

class SparkStatusCodes {
  static const String SPARK_JOB_STATUS_UNKNOWN = "spark.job.status_unknown";
  static const String SPARK_JOB_BUILD_SUCCESS = 'spark.job.build_success';
}

class SparkStatusMessages {
  static const String SPARK_JOB_BUILD_SUCCESS_MSG = 'Build Successful!!';
}
