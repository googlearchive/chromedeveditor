/**
 * A tuple of an AST and a list of errors.
 */
class AnalyzerResult {
  final CompilationUnit ast;
  final AnalysisErrorInfo errorInfo;

  AnalyzerResult(this.ast, this.errorInfo);

  List<AnalysisError> get errors => errorInfo.errors;

  LineInfo_Location getLineInfo(AnalysisError error) {
    return errorInfo.lineInfo.getLocation(error.offset);
  }

  String toString() => 'AnalyzerResult[${errorInfo.errors.length} issues]';
}


class LineInfo_Location {
  final int lineNumber;
  final int columnNumber;
  LineInfo_Location(this.lineNumber, this.columnNumber);
}

abstract class AnalysisErrorInfo {
  List<AnalysisError> get errors;
  LineInfo get lineInfo;
}

class AnalysisError {
  static List<AnalysisError> NO_ERRORS = new List<AnalysisError>(0);
  static Comparator<AnalysisError> FILE_COMPARATOR;
  static Comparator<AnalysisError> ERROR_CODE_COMPARATOR = (AnalysisError o1, AnalysisError o2);

  /**
   * The error code associated with the error.
   */
  final ErrorCode errorCode;
  Source source;
  bool isStaticOnly = false;
  AnalysisError(this.source, int offset, int length, this.errorCode, List<Object> arguments) {
    this.offset = offset;
    this.length = length;
    this._message = JavaString.format(errorCode.message, arguments);
    String correctionTemplate = errorCode.correction;
    if (correctionTemplate != null) {
      this._correction = JavaString.format(correctionTemplate, arguments);
    }
  }

  String get correction => _correction;
  int length;
  String message;
  int offset;
  Object getProperty(ErrorProperty property) => null;
}


abstract class ErrorCode {
  String get correction;
  ErrorSeverity get errorSeverity;
  String get message;
  ErrorType get type;
}

class ErrorType extends Enum<ErrorType> {
  static final ErrorType TODO = new ErrorType('TODO', 0, ErrorSeverity.INFO);
  static final ErrorType HINT = new ErrorType('HINT', 1, ErrorSeverity.INFO);
  static final ErrorType COMPILE_TIME_ERROR = new ErrorType('COMPILE_TIME_ERROR', 2, ErrorSeverity.ERROR);
  static final ErrorType PUB_SUGGESTION = new ErrorType('PUB_SUGGESTION', 3, ErrorSeverity.WARNING);
  static final ErrorType STATIC_WARNING = new ErrorType('STATIC_WARNING', 4, ErrorSeverity.WARNING);
  static final ErrorType STATIC_TYPE_WARNING = new ErrorType('STATIC_TYPE_WARNING', 5, ErrorSeverity.WARNING);
  static final ErrorType SYNTACTIC_ERROR = new ErrorType('SYNTACTIC_ERROR', 6, ErrorSeverity.ERROR);
  static final ErrorType TOOLKIT = new ErrorType('TOOLKIT', 7, ErrorSeverity.INFO);

  static final List<ErrorType> values = [
      TODO,
      HINT,
      COMPILE_TIME_ERROR,
      PUB_SUGGESTION,
      STATIC_WARNING,
      STATIC_TYPE_WARNING,
      SYNTACTIC_ERROR,
      TOOLKIT];

  final ErrorSeverity severity;

  ErrorType(String name, int ordinal, this.severity) : super(name, ordinal);

  String get displayName => name.toLowerCase().replaceAll('_', ' ');
}

class ErrorSeverity extends Enum<ErrorSeverity> {
  static final ErrorSeverity NONE = new ErrorSeverity('NONE', 0, " ", "none");
  static final ErrorSeverity INFO = new ErrorSeverity('INFO', 1, "I", "info");
  static final ErrorSeverity WARNING = new ErrorSeverity('WARNING', 2, "W", "warning");
  static final ErrorSeverity ERROR = new ErrorSeverity('ERROR', 3, "E", "error");
  static final List<ErrorSeverity> values = [NONE, INFO, WARNING, ERROR];
  final String machineCode;
  final String displayName;
  ErrorSeverity max(ErrorSeverity severity) => this.ordinal >= severity.ordinal ? this : severity;
}


class LineInfo {
  List<int> _lineStarts;
  LineInfo(List<int> lineStarts) {
  }

  LineInfo_Location getLocation(int offset) {
    int lineCount = _lineStarts.length;
    for (int i = 1; i < lineCount; i++) {
      if (offset < _lineStarts[i]) {
        return new LineInfo_Location(i, offset - _lineStarts[i - 1] + 1);
      }
    }
    return new LineInfo_Location(lineCount, offset - _lineStarts[lineCount - 1] + 1);
  }
}

