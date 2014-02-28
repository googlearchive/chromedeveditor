// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

class AnalysisResult {
  AnalysisResult.fromMap(Map mapData) {
  }
}

class AnalysisError {
  String message;
  int offset;
  int lineNumber;
  int errorSeverity;
  int length;

  AnalysisError();

  AnalysisError.fromMap(Map mapData) {
    message = mapData["message"];
    offset = mapData["offset"];
    lineNumber = mapData["lineNumber"];
    errorSeverity = mapData["errorSeverity"];
    length = mapData["length"];
  }

  Map toMap() {
    return {
        "message": message,
        "offset": offset,
        "lineNumber": lineNumber,
        "errorSeverity": errorSeverity,
        "length": length
    };
  }
}

class ErrorSeverity {
  static int NONE = 0;
  static int ERROR = 1;
  static int WARNING = 2;
  static int INFO = 3;
}