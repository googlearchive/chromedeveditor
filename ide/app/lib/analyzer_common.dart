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

  AnalysisError.fromMap(Map mapData) {
    message = mapData["message"];
    offset = mapData["offset"];
    lineNumber = mapData["lineNumber"];
    errorSeverity = mapData["errorSeverity"];
    length = mapData["length"];
  }

  Map toMap(Map mapData) {
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
  static int ERROR = 1;
  static int WARNING = 2;
  static int INFO = 3;
}