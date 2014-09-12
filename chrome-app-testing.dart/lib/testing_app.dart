// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library chrome_testing.app;

import 'dart:async';
import 'dart:convert';
import 'dart:html';

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:chrome_net/tcp.dart' as tcp;
import 'package:logging/logging.dart';
import 'package:unittest/unittest.dart' as unittest;

const int _DEFAULT_TESTPORT = 5120;

Logger _logger = new Logger('tests');

/**
 * A class used to drive unit tests and report results in a Chrome App setting.
 */
class TestDriver {
  Function _defineTestsFn;

  StreamSubscription _logListener;
  StreamController<unittest.TestCase> _onTestFinished =
      new StreamController.broadcast();

  Element _testDiv;
  Element _statusDiv;

  Completer<bool> _testCompleter;

  TestDriver(this._defineTestsFn, {bool connectToTestListener: false}) {
    unittest.unittestConfiguration = new _TestConfiguration(this);

    if (connectToTestListener) {
      _connectToListener();
    }
  }

  /**
   * Run the tests and return back whether they passed.
   */
  Future<bool> runTests() {
    if (_logListener == null) {
      _createTestUI();
    }

    _testDiv.style.display = 'inline';
    _statusDiv.style.background = 'rgb(84, 180, 84)';
    _statusDiv.text = '';

    _testCompleter = new Completer();

    if (_defineTestsFn != null) {
      _defineTestsFn();
      _defineTestsFn = null;
    }

    unittest.runTests();

    return _testCompleter.future;
  }

  Stream<unittest.TestCase> get onTestFinished => _onTestFinished.stream;

  void testFinished(unittest.TestCase test) {
    _onTestFinished.add(test);
  }

  void _connectToListener() {
    // Try to connect to a pre-defined port.
    _TestListenerClient.connect().then((_TestListenerClient testClient) {
      if (testClient == null) return;

      print('Connected to test listener on port ${testClient.port}');

      Logger.root.onRecord.listen((LogRecord r) {
        testClient.log('${r}');
      });

      _logger.info('Running tests on ${window.navigator.appCodeName} '
          '${window.navigator.appName} ${window.navigator.appVersion}');

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
    _testDiv.style.bottom = '8px';
    _testDiv.style.left = '8px';
    _testDiv.style.right = '8px';
    _testDiv.style.display = 'none';

    _statusDiv = new DivElement();
    _statusDiv.style.padding = '2px';
    _statusDiv.style.background = 'rgb(84, 180, 84)';
    _statusDiv.style.borderRadius = '2px';
    _statusDiv.style.fontFamily = 'monospace';
    _testDiv.nodes.add(_statusDiv);

    _logger.onRecord.listen((LogRecord record) {
      if (record.level >= Level.SEVERE) {
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
    Future f = tcp.TcpClient.createClient(tcp.LOCAL_HOST, port, throwOnError: false);
    return f.then((tcp.TcpClient client) {
      return client == null ? null : new _TestListenerClient._(port, client);
    });
  }

  _TestListenerClient._(this.port, this._tcpClient);

  /**
   * Send a line of output to the test listener.
   */
  void log(String str) => _tcpClient.write(UTF8.encode('${str}\n'));
}

class _TestConfiguration extends unittest.Configuration {
  final TestDriver testDriver;

  _TestConfiguration(this.testDriver): super.blank();

  bool get autoStart => false;

  Duration get timeout => const Duration(seconds: 30);

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
      String st = '';

      if (test.stackTrace != null && test.stackTrace != '') {
        st = '\n' + indent(test.stackTrace.toString().trim(), '    ');
      }

      _logger.severe(
          '${test.result} ${test.description}\n${test.message.trim()}${st}\n');
    } else {
      _logger.info("${test.result} ${test.description}\n");
    }

    testDriver.testFinished(test);
  }

  void onSummary(int passed, int failed, int errors,
      List<unittest.TestCase> results, String uncaughtError) {
    for (unittest.TestCase test in results) {
      if (test.result != unittest.PASS) {
        String st = '';

        if (test.stackTrace != null && test.stackTrace != '') {
          st = '\n' + indent(test.stackTrace.toString().trim(), '    ');
        }

        _logger.severe(
            '${test.result}: ${test.description}\n${test.message.trim()}${st}');
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

      _logger.warning('$passed tests passed, $failed failed, and $errors '
          'errored.');
    }
  }

  String indent(String str, [String indent = '  ']) {
    return str.split("\n").map((line) => "${indent}${line}").join("\n");
  }
}

String _fixed(String str, int width) {
  if (str.length > width) return str.substring(0, width);

  switch (width - str.length) {
    case 0: return str;
    case 1: return '${str} ';
    case 2: return '${str}  ';
    case 3: return '${str}   ';
    case 4: return '${str}    ';
    case 5: return '${str}     ';
    case 6: return '${str}      ';
    case 7: return '${str}       ';
    case 8: return '${str}        ';
    case 9: return '${str}         ';
    default: return str;
  }
}
