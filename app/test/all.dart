
/**
 * This library serves to:
 * * define all tests for the Spark app (defined in [_defineTests])
 * * log test results to the `'spark.tests'` [Logger] instance
 * * provide an API to programmatically run all the tests, and asynchronously
 *   report back on whether the tests passed or failed
 */
library spark.tests;

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:unittest/unittest.dart' as unittest;

import 'utils_test.dart' as utils_test;

bool _testsDefined = false;

Logger logger = new Logger('spark.tests');

Completer<bool> _completer;

/**
 * Place all new tests here. This method is only called once; [runTests] can be
 * called multiple times.
 */
void _defineTests() {
  unittest.unittestConfiguration = new SparkTestConfiguration();
  logger.onRecord.listen(_logToStdout);

  utils_test.main();
}

/**
 * Run all the Spark tests and report back when they finish. The returned
 * [Future] indicates whether the tests had failures or not.
 */
Future<bool> runTests() {
  if (_completer != null) {
    _completer.completeError('timeout');
  }

  if (!_testsDefined) {
    _defineTests();
    _testsDefined = true;
  }

  _completer = new Completer();

  unittest.rerunTests();

  return _completer.future;
}

void _logToStdout(LogRecord record) {
  print(
      '[${record.loggerName} '
      '${record.level.toString().toLowerCase()}] '
      '${record.message}');
}

class SparkTestConfiguration implements unittest.Configuration {

  bool get autoStart => false;

  Duration timeout = const Duration(seconds: 5);

  void onInit() {

  }

  void onStart() {

  }

  void onDone(bool success) {
    if (_completer != null) {
      _completer.complete(success);
      _completer = null;
    }
  }

  void onLogMessage(unittest.TestCase testCase, String message) {
    logger.info(message);
  }

  void onTestStart(unittest.TestCase testCase) {

  }

  void onTestResultChanged(unittest.TestCase testCase) {

  }

  void onTestResult(unittest.TestCase testCase) {

  }

  void onSummary(int passed, int failed, int errors,
      List<unittest.TestCase> results, String uncaughtError) {
    for (unittest.TestCase test in results) {
      logger.info('${test.result}: ${test.description}');

      if (test.message != '') {
        logger.warning(test.message);
      }

      if (test.stackTrace != null && test.stackTrace != '') {
        logger.warning(indent(test.stackTrace.toString()));
      }
    }

    if (passed == 0 && failed == 0 && errors == 0 && uncaughtError == null) {
      logger.warning('No tests found.');
    } else if (failed == 0 && errors == 0 && uncaughtError == null) {
      logger.info('All $passed tests passed!');
    } else {
      if (uncaughtError != null) {
        logger.severe('Top-level uncaught error: $uncaughtError');
      }

      logger.warning('$passed PASSED, $failed FAILED, $errors ERRORS');
    }
  }

  String indent(String str) {
    return str.split("\n").map((line) => "  $line").join("\n");
  }
}
