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

import 'package:chrome_gen/chrome_app.dart' as chrome_gen;
import 'package:logging/logging.dart';

import 'spark.dart';
import 'lib/tcp.dart' as tcp;
import 'test/all.dart' as tests;

Logger testLogger = new Logger('spark.tests');

/**
 * A custom subclass of Spark with tests built-in.
 */
class SparkTest extends Spark {
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
      testClient.log(
          '[${record.loggerName} '
          '${record.level.toString().toLowerCase()}] '
          '${record.message}');
    });

    tests.runTests().then((bool success) {
      testClient.log('test exit code: ${(success ? 0 : 1)}');

      chrome_gen.app.window.current().close();
    });
  }

  /**
   * Display a UI to drive unit tests. This floats over the window's content.
   */
  void showTestUI() {
    DivElement div = new DivElement();
    div.style.zIndex = '100';
    div.style.position = 'fixed';
    div.style.bottom = '0px';
    div.style.marginBottom = '0.5em';
    div.style.marginLeft = '0.5em';
    div.style.background = 'green';
    div.style.borderRadius = '4px';
    div.style.opacity = '0.7';

    ButtonElement button = new ButtonElement();
    button.text = "Run Tests";
    div.nodes.add(button);

    SpanElement status = new SpanElement();
    status.style.marginRight = '0.5em';
    status.style.display = 'none';
    div.nodes.add(status);

    button.onClick.listen((e) {
      div.style.background = 'green';
      status.style.display = 'inline';
      status.text = '';
      button.disabled = true;
      tests.runTests().then((bool success) {
        button.disabled = false;
      });
    });

    testLogger.onRecord.listen((LogRecord record) {
      if (record.level > Level.INFO) {
        div.style.background = 'red';
      }

      if (status.style.display != 'inline') {
        status.style.display = 'inline';
      }

      status.text =
          '[${record.loggerName} '
          '${record.level.toString().toLowerCase()}] '
          '${record.message}';
    });

    document.body.nodes.add(div);
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
