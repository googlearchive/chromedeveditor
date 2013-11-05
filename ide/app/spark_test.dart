// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This custom version of Spark allows us to run the suite of tests, either in
 * a manual or an automated fashion.
 */
library spark_test;

import 'dart:async';
import 'dart:html';

import 'package:chrome_gen/chrome_app.dart' as chrome;
import 'package:logging/logging.dart';

import 'spark.dart';
import 'lib/tcp.dart' as tcp;
import 'test/all.dart' as tests;

Logger testLogger = new Logger('spark.tests');

/**
 * A custom subclass of Spark with tests built-in.
 */
class SparkTest extends Spark {
  DivElement _testDiv;
  SpanElement _status;

  SparkTest() {
    print('Running Spark in test mode');
  }

  void connectToListener() {
    // try to connect to a pre-defined port
    TestListenerClient.connect()
        .then(runTests)
        .catchError((e) => print(e));
  }

  void runTests(TestListenerClient testClient) {
    print('Connected to test listener on port ${testClient.port}');

    testLogger.onRecord.listen((LogRecord record) {
      testClient.log(record.toString());
    });

    tests.runTests().then((bool success) {
      testClient.log('test exit code: ${(success ? 0 : 1)}');

      chrome.app.window.current().close();
    });
  }

  /**
   * Display a UI to drive unit tests. This floats over the window's content.
   */
  void showTestUI() {
    chrome.contextMenus.create({
      'title': "Spark: Run Tests",
      'id': 'run_tests',
      'contexts': [ 'all' ]
    });

    chrome.contextMenus.onClicked.listen((chrome.OnClickedEvent e) {
      if (e.info.menuItemId == 'run_tests') {
        _runTests();
      }
    });

    _testDiv = new DivElement();
    _testDiv.style.zIndex = '100';
    _testDiv.style.position = 'fixed';
    _testDiv.style.bottom = '0px';
    _testDiv.style.marginBottom = '0.5em';
    _testDiv.style.marginLeft = '0.5em';
    _testDiv.style.background = 'green';
    _testDiv.style.borderRadius = '2px';
    _testDiv.style.opacity = '0.8';
    _testDiv.style.display = 'none';

    _status = new SpanElement();
    _status.style.margin = '0.5em';
    _testDiv.nodes.add(_status);

    testLogger.onRecord.listen((LogRecord record) {
      if (record.level > Level.INFO) {
        _testDiv.style.background = 'red';
      }
      _status.text = record.toString();
    });

    document.body.nodes.add(_testDiv);
  }

  void _runTests() {
    _testDiv.style.display = 'inline';
    _testDiv.style.background = 'green';
    _status.text = '';
    tests.runTests();
  }
}

/**
 * A class to connect to an existing test listener, and write test output to it.
 */
class TestListenerClient {
  static const int DEFAULT_TESTPORT = 5120;

  final int port;
  final tcp.TcpClient _tcpClient;

  /**
   * Try to connect to a test listener on the given port, and return a new
   * instance of [TestListenerClient] on success.
   */
  static Future<TestListenerClient> connect([int port = DEFAULT_TESTPORT]) {
    return tcp.TcpClient.createClient(tcp.LOCAL_HOST, port)
        .then((tcp.TcpClient client) {
          return new TestListenerClient._(port, client);
        })
        .catchError((e) {
          throw 'No test listener available on port ${port}';
        });
  }

  TestListenerClient._(this.port, this._tcpClient);

  /**
   * Send a line of output to the test listener.
   */
  void log(String str) {
    _tcpClient.writeString('${str}\n');
  }
}
