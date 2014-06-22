// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.status;

import 'exception.dart';

class SparkJobStatus {
  String _message;
  String code = SparkStatusCodes.SPARK_JOB_STATUS_UNKNOWN;

  /// Indicates whether the job was successful or failed.
  bool success = true;

  /// The underlining exception object in case the job failed.
  SparkException exception;

  get String message => _message;

  set message(String msg) => _message = msg;

  SparkJobStatus({this.code, String message}) {
    if (message == null) {
      try {
        _message = getStatusMessageFromCode(this.code);
      } catch (e) {
        // Do Nothing.
      }
    } else {
      _message = message;
    }
  }

  static String getStatusMessageFromCode(String code) {
    switch (code) {
      case SparkStatusCodes.SPARK_JOB_BUILD_SUCCESS:
        return SparkStatusMessages.SPARK_JOB_BUILD_SUCCESS_MSG;

      case SparkStatusCodes.SPARK_JOB_IMPORT_FOLDER_SUCCESS:
        return SparkStatusMessages.SPARK_JOB_IMPORT_FOLDER_SUCCESS_MSG;

      case SparkStatusCodes.SPARK_JOB_GIT_PULL_SUCCESS:
        return SparkStatusMessages.SPARK_JOB_GIT_PULL_SUCCESS_MSG;
      case SparkStatusCodes.SPARK_JOB_GIT_COMMIT_SUCCESS:
        return SparkStatusMessages.SPARK_JOB_GIT_COMMIT_SUCCESS_MSG;
      case SparkStatusCodes.SPARK_JOB_GIT_ADD_SUCCESS:
        return SparkStatusMessages.SPARK_JOB_GIT_ADD_SUCCESS_MSG;
    }
    throw "Message for code : ${code} not found.";
  }
}

class SparkStatusCodes {

  static const String SPARK_JOB_STATUS_OK = "spark.job.status_ok";
  static const String SPARK_JOB_STATUS_UNKNOWN = "spark.job.status_unknown";

  static const String SPARK_JOB_IMPORT_FOLDER_SUCCESS = "spark.job.import.folder_success";

  static const String SPARK_JOB_BUILD_SUCCESS = 'spark.job.build_success';

  static const String SPARK_JOB_GIT_PULL_SUCCESS = "spark.job.git.pull_success";
  static const String SPARK_JOB_GIT_COMMIT_SUCCESS = "spark.job.git.commit_success";
  static const String SPARK_JOB_GIT_ADD_SUCCESS = "spark.job.git.add_success";
}

class SparkStatusMessages {
  static const String SPARK_JOB_BUILD_SUCCESS_MSG = 'Build successful.';

  static const String SPARK_JOB_IMPORT_FOLDER_SUCCESS_MSG = "Import successful.";

  static const String SPARK_JOB_GIT_PULL_SUCCESS_MSG = "Pull successful.";
  static const String SPARK_JOB_GIT_COMMIT_SUCCESS_MSG = "Changes committed.";
  static const String SPARK_JOB_GIT_ADD_SUCCESS_MSG = "Added successfully.";
}
