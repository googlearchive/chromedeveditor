// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.tests;

import 'dart:async';
import 'dart:html';

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:logging/logging.dart';
import 'package:unittest/unittest.dart' as unittest;

import 'jobs.dart';
import 'tcp.dart' as tcp;

const int _DEFAULT_TESTPORT = 5120;

Logger _logger = new Logger('spark.tests');

/**
 * A class used to drive unit tests and report results in a Chrome App setting.
 */
class TestDriver {
  final JobManager _jobManager;

  Function _defineTestsFn;
  Element _testDiv;
  Element _statusDiv;

  Completer<bool> _testCompleter;

  TestDriver(this._defineTestsFn, this._jobManager, {bool connectToTestListener: false}) {
    unittest.unittestConfiguration = new _SparkTestConfiguration(this);
    _logger.onRecord.listen((record) => print(record.toString()));

    if (connectToTestListener) {
      _connectToListener();
    }

    _createTestUI();
  }

  /**
   * Run the tests and return back whether they passed.
   */
  Future<bool> runTests() {
    _testDiv.style.display = 'inline';
    _statusDiv.style.background = 'rgb(84, 180, 84)';
    _statusDiv.text = '';

    _testCompleter = new Completer();

    if (_defineTestsFn != null) {
      _defineTestsFn();
      _defineTestsFn = null;
    }

    _TestJob job = new _TestJob(this, _testCompleter);
    _jobManager.schedule(job);

    return _testCompleter.future;
  }

  void _connectToListener() {
    // Try to connect to a pre-defined port.
    _TestListenerClient.connect().then((_TestListenerClient testClient) {
      if (testClient == null) {
        return;
      }

      print('Connected to test listener on port ${testClient.port}');

      _logger.onRecord.listen((LogRecord record) {
        testClient.log(record.toString());
      });

      _logger.info('Running tests on ${window.navigator.appCodeName} ${window.navigator.appName} ${window.navigator.appVersion}');

      runTests().then((bool success) {
        testClient.log('test exit code: ${(success ? 0 : 1)}');

        chrome.app.window.current().close();
      });
    }).catchError((e) => null);
  }

  /**
   * Display a UI to drive unit tests. This floats over the window's content.
   */
  void _createTestUI() {
    _testDiv = new DivElement();
    _testDiv.style.zIndex = '100';
    _testDiv.style.position = 'fixed';
    _testDiv.style.bottom = '0px';
    _testDiv.style.padding = '0.5em';
    _testDiv.style.width = '100%';
    _testDiv.style.display = 'none';

    _statusDiv = new DivElement();
    _statusDiv.style.padding = '0 0.5em';
    _statusDiv.style.background = 'rgb(84, 180, 84)';
    _statusDiv.style.borderRadius = '2px';
    _testDiv.nodes.add(_statusDiv);

    _logger.onRecord.listen((LogRecord record) {
      if (record.level > Level.INFO) {
        _statusDiv.style.background = 'red';
      }
      _statusDiv.text = record.toString();
    });

    document.body.nodes.add(_testDiv);
  }

  void _testsFinished(bool sucess) {
    _testCompleter.complete(sucess);
  }
}

class _TestJob extends Job {
  final TestDriver testDriver;
  final Completer<bool> testCompleter;

  _TestJob(this.testDriver, this.testCompleter) : super("Running tests…");

  Future<Job> run(ProgressMonitor monitor) {
    // TODO: Count tests for future progress bar.
    monitor.start(name, 1);

    unittest.rerunTests();

    return testCompleter.future.then((_) => this);
  }
}

/**
 * A class to connect to an existing test listener and write test output to it.
 */
class _TestListenerClient {
  final int port;
  final tcp.TcpClient _tcpClient;

  /**
   * Try to connect to a test listener on the given port, and return a new
   * instance of [TestListenerClient] on success.
   */
  static Future<_TestListenerClient> connect([int port = _DEFAULT_TESTPORT]) {
    return tcp.TcpClient.createClient(tcp.LOCAL_HOST, port, throwOnError: false)
        .then((tcp.TcpClient client) {
          return client == null ? null : new _TestListenerClient._(port, client);
        });
  }

  _TestListenerClient._(this.port, this._tcpClient);

  /**
   * Send a line of output to the test listener.
   */
  void log(String str) {
    _tcpClient.writeString('${str}\n');
  }
}

class _SparkTestConfiguration extends unittest.Configuration {
  TestDriver testDriver;

  _SparkTestConfiguration(this.testDriver): super.blank();

  bool get autoStart => false;

  Duration get timeout => const Duration(seconds: 5);

  void onStart() {

  }

  void onDone(bool success) {
    testDriver._testsFinished(success);
  }

  void onLogMessage(unittest.TestCase testCase, String message) {
    _logger.info(message);
  }

  void onTestStart(unittest.TestCase test) {
    _logger.info('running ${test.description}');
  }

  void onTestResult(unittest.TestCase test) {
    if (test.result != unittest.PASS) {
      _logger.warning("${test.result} ${test.description}");
    }
  }

  void onSummary(int passed, int failed, int errors,
      List<unittest.TestCase> results, String uncaughtError) {
    for (unittest.TestCase test in results) {
      if (test.result == unittest.PASS) {
        _logger.info('${test.result}: ${test.description}');
      } else {
        String stackTrace = '';

        if (test.stackTrace != null && test.stackTrace != '') {
          stackTrace = '\n' + indent(test.stackTrace.toString().trim(), '    ');
        }

        _logger.warning('${test.result}: ${test.description}\n' +
            test.message.trim() + stackTrace);
      }
    }

    if (passed == 0 && failed == 0 && errors == 0 && uncaughtError == null) {
      _logger.warning('No tests found.');
    } else if (failed == 0 && errors == 0 && uncaughtError == null) {
      _logger.info('All $passed tests passed!');
    } else {
      if (uncaughtError != null) {
        _logger.severe('Top-level uncaught error: $uncaughtError');
      }

      _logger.warning(
          '$passed tests passed, $failed failed, and $errors errored.');
    }
  }

  String indent(String str, [String indent = '  ']) {
    return str.split("\n").map((line) => "${indent}${line}").join("\n");
  }
}
