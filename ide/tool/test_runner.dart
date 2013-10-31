// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This test runner is used to drive the Spark unit tests in an automated
 * fashion. The general flow is:
 *
 * - start a test listener
 * - start Chrome with --load-and-launch-app=spark/app
 * - handle test output, check for test timeout
 * - kill process
 * - report back with test results and exit code
 */
library test_runner;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:grinder/grinder.dart';

TestListener testListener;
Process chromeProcess;
int exitCode;
Directory tempDir;

final int TEST_TIMEOUT = 10;
final int CHROME_SHUTDOWN_TIMEOUT = 1;
final int EXIT_PROCESS_TIMEOUT = 1;

void main() {
  if (!new Directory('app').existsSync()) {
    throw 'This script must be run from the root of the project directory.';
  }

  ArgParser parser = _createArgsParser();
  ArgResults results = parser.parse(new Options().arguments);

  String appPath = null;
  String browserPath = null;

  if (results['dartium']) {
    appPath = 'app';
    browserPath = _dartiumPath();
  }

  if (results['chrome'] || results['chrome-stable']) {
    appPath = 'app';
    //appPath = 'build/deploy-test-out/web';
    browserPath = _chromeStablePath();
  }

  if (results['chrome-dev']) {
    appPath = 'app';
    //appPath = 'build/deploy-test-out/web';
    browserPath = _chromeDevPath();
  }

//  if (results['appPath'] != null) {
//    appPath = results['appPath'];
//  }
//
//  if (results['browserPath'] != null) {
//    browserPath = results['browserPath'];
//  }

  if (appPath == null || browserPath == null) {
    _printUsage(parser);
    return;
  }

  // start a test listener
  TestListener.create().then((TestListener listener) {
    testListener = listener;

    runApp(browserPath, appPath);
  }).catchError(_fatalError);
}

void runApp(String browserPath, String appPath) {
  tempDir = Directory.systemTemp.createTempSync('userDataDir-');

  String path = new Directory(appPath).absolute.path;

  List<String> args = [
      '--no-default-browser-check',
      '--no-first-run',
      '--user-data-dir=${tempDir.path}',
      '--load-and-launch-app=${path}'
  ];

  if (Platform.isMacOS) {
    // TODO: does this work on OSes other then mac?
    args.add('--no-startup-window');
  }

  log("starting chrome...");
  log('"${browserPath}" ${args.join(' ')}');

  Process.start(browserPath, args, workingDirectory: appPath)
    .then((Process process) {
      chromeProcess = process;

      chromeProcess.exitCode.then((int exitCode) {
        log("Chrome process finished [${exitCode}]");
        chromeProcess = null;
      });
    })
    .catchError(_fatalError);
}

void log(String str) => print("[${str}]");

ArgParser _createArgsParser() {
  ArgParser parser = new ArgParser();
  parser.addFlag('dartium',
      help: 'run in dartium, test the app in app/', negatable: false);
  parser.addFlag('chrome',
      help: 'an alias to --chrome-stable', negatable: false);
  parser.addFlag('chrome-stable',
      help: 'run in chrome stable, test the app in build/deploy-test-out/web/', negatable: false);
  parser.addFlag('chrome-dev',
      help: 'run in chrome dev, test the app in build/deploy-test-out/web/', negatable: false);

//  parser.addOption('appPath', help: 'the application path to run');
//  parser.addOption('browserPath', help: 'the path to chrome');

  return parser;
}

void _printUsage(ArgParser parser) {
  print('usage: dart ${Platform.script} <options>');
  print('');
  print('valid options:');
  print(parser.getUsage().replaceAll('\n\n', '\n'));
  print('');
  print('Generally, you should run this tool with either --dartium or --chrome-*.');
  print('Optionally, you can specify the browser to run the app in, and the application');
  print('directory to launch.');
}

String _dartiumPath() {
  final Map m = {
    "linux": "chrome",
    "macos": "Chromium.app/Contents/MacOS/Chromium",
    "windows": "Chromium.exe"
  };

  String path = "${sdkDir.path}/../chromium/${m[Platform.operatingSystem]}";

  if (FileSystemEntity.isFileSync(path)) {
    return new File(path).absolute.path;
  } else {
    throw 'unable to locate Dartium (${path})';
  }
}

String _chromeStablePath() {
  if (Platform.isLinux) {
    return '/usr/bin/google-chrome';
  } else if (Platform.isMacOS) {
    return '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
  } else {
    // TODO: locate Chrome on Windows
    throw 'unable to locate Chrome; ${Platform.operatingSystem} not yet supported';
  }
}

String _chromeDevPath() {
  if (Platform.isLinux) {
    return '/usr/bin/google-chrome-unstable';
  } else {
    // TODO:
    throw 'unable to locate Chrome dev; ${Platform.operatingSystem} not yet supported';
  }
}

void _fatalError(e) {
  if (chromeProcess != null) {
    chromeProcess.kill();
  }

  log(e);

  _doExit(1);
}

void _testsFinished(int inExitCode) {
  if (exitCode != null) {
    return;
  }

  exitCode = inExitCode;

  testListener.close();

  // Give the chrome process a little time to shut down on its own.
  new Timer(new Duration(seconds: CHROME_SHUTDOWN_TIMEOUT), () {
    if (chromeProcess != null) {
        if (chromeProcess != null) {
          chromeProcess.kill();
        }
        _doExit(exitCode);
    } else {
      _doExit(exitCode);
    }
  });
}

void _streamClosed() {
  // We exit here with an error. If we already recieved a "exit code: xxx", then
  // this error exit will be ignored. This covers the case where the stream is
  // closed by the test client before we're notified of the test results.
  _testsFinished(1);
}

void _doExit(int code) {
  new Timer(new Duration(seconds: EXIT_PROCESS_TIMEOUT), () {
    if (tempDir != null) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (e) {
        // We don't want issues deleting the temp directory to fail the tests.
        print(e);
      }
    }
    exit(code);
  });
}

class TestListener {
  static const int DEFAULT_TESTPORT = 5120;
  static final String FINISHED_TOKEN = 'exit code:';

  ServerSocket serverSocket;
  Socket socket;
  Timer connectTimer;
  Timer testOutputTimer;

  static Future<TestListener> create([int port = DEFAULT_TESTPORT]) {
    return ServerSocket.bind(InternetAddress.LOOPBACK_IP_V4, port)
        .then((ServerSocket ss) => new TestListener._(ss));
  }

  TestListener._(this.serverSocket) {
    log("test listener listening on port ${serverSocket.port}");

    connectTimer = new Timer(new Duration(seconds: TEST_TIMEOUT),
        () => _fatalError('timeout waiting for test client connection'));

    serverSocket.listen(_handleConnection);
  }

  void _handleConnection(Socket socket) {
    connectTimer.cancel();

    this.socket = socket;

    _resetReadTimer();

    socket.transform(UTF8.decoder).listen((String str) {
      stdout.write(str);

      _resetReadTimer();

      if (str.contains(FINISHED_TOKEN)) {
        RegExp regex = new RegExp('${FINISHED_TOKEN}\\s(\\d+)');
        Match match = regex.firstMatch(str);

        if (match != null) {
          String code = match.group(1);
          _testsFinished(int.parse(code));
        } else {
          _testsFinished(1);
        }
      }
    }, onDone: _streamClosed);
  }

  void _resetReadTimer() {
    if (testOutputTimer != null) {
      testOutputTimer.cancel();
    }

    testOutputTimer = new Timer(new Duration(seconds: TEST_TIMEOUT),
        () => _fatalError('timeout waiting for test results'));
  }

  void close() {
    log("closing test listener");

    if (socket != null) {
      socket.close();
    }

    serverSocket.close();
  }
}
