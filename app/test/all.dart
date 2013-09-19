
library spark.tests;

import 'package:unittest/unittest.dart';

import 'utils_test.dart' as utils_test;

bool _testsDefined = false;

void runTests() {
  if (_testsDefined) {
    rerunTests();
  } else {
    unittestConfiguration = new WorkbenchTestConfiguration();

    _defineTests();
    rerunTests();
  }
}

void _defineTests() {
  utils_test.main();

  _testsDefined = true;
}

class WorkbenchTestConfiguration implements Configuration {
  WorkbenchTestConfiguration();

  bool get autoStart => false;

  Duration timeout = const Duration(seconds: 5);

  void onInit() {

  }

  void onStart() {

  }

  void onDone(bool success) {

  }

  void onLogMessage(TestCase testCase, String message) {
    print(message);
  }

  void onTestStart(TestCase testCase) {

  }

  void onTestResultChanged(TestCase testCase) {

  }

  void onTestResult(TestCase testCase) {

  }

  void onSummary(int passed, int failed, int errors,
                 List<TestCase> results, String uncaughtError) {
    for (TestCase test in results) {
      print('${test.result}: ${test.description}');

      if (test.message != '') {
        print(test.message);
      }

      if (test.stackTrace != null && test.stackTrace != '') {
        print(indent(test.stackTrace.toString()));
      }
    }

    if (passed == 0 && failed == 0 && errors == 0 && uncaughtError == null) {
      print('No tests found.');
    } else if (failed == 0 && errors == 0 && uncaughtError == null) {
      print('All $passed tests passed!');
    } else {
      if (uncaughtError != null) {
        print('Top-level uncaught error: $uncaughtError');
      }

      print('$passed PASSED, $failed FAILED, $errors ERRORS');
    }
  }

  String indent(String str) {
    return str.split("\n").map((line) => "  $line").join("\n");
  }

}
