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

final int TEST_TIMEOUT = 30;
final int CHROME_SHUTDOWN_TIMEOUT = 1;
final int EXIT_PROCESS_TIMEOUT = 1;

void main([List<String> args = const []]) {
  if (!new Directory('app').existsSync()) {
    print('This script must be run from the root of the project directory.');
    exit(1);
  }

  if (!_canLocateSdk()) {
    print('Unable to locate the Dart SDK; please set the DART_SDK env variable');
    exit(1);
  }

  ArgParser parser = _createArgsParser();
  ArgResults results = parser.parse(args);

  String appPath = null;
  String browserPath = null;

  if (results['dartium']) {
    appPath = 'app';
    browserPath = _dartiumPath();
  }

  if (results['chrome'] || results['chrome-stable']) {
    //appPath = 'app';
    appPath = 'build/deploy-out/web';
    //browserPath = _chromeStablePath();
    browserPath = _dartiumPath();
  }

  if (results['chrome-dev']) {
    //appPath = 'app';
    appPath = 'build/deploy-out/web';
    //browserPath = _chromeDevPath();
    browserPath = _dartiumPath();
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

    runApp(browserPath, appPath, verbose: results['verbose']);
  }).catchError(_fatalError);
}

void runApp(String browserPath, String appPath, {bool verbose: false}) {
  tempDir = Directory.systemTemp.createTempSync('userDataDir-');

  String path = new Directory(appPath).absolute.path;

  List<String> args = [
      '--enable-experimental-web-platform-features',
      '--enable-html-imports',
      '--no-default-browser-check',
      '--no-first-run',
      '--user-data-dir=${tempDir.path}',
      '--load-and-launch-app=${path}'
  ];

  if (verbose) {
    args.addAll(['--enable-logging=stderr', '--v=1']);
  }

  if (Platform.isMacOS) {
    // TODO: does this work on OSes other then mac?
    args.add('--no-startup-window');
  }

  log("starting chrome...");
  log('"${browserPath}" ${args.join(' ')}');

  Process.start(browserPath, args, workingDirectory: appPath)
    .then((Process process) {
      chromeProcess = process;

      chromeProcess.stdout.transform(new Utf8Decoder())
                          .transform(new LineSplitter())
                          .listen((String line) => print(line));
      chromeProcess.stderr.transform(new Utf8Decoder())
                          .transform(new LineSplitter())
                          .listen((String line) => print(line));

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
      help: 'run in chrome stable, test the app in build/deploy-out/web/',
      negatable: false);
  parser.addFlag('chrome-dev',
      help: 'run in chrome dev, test the app in build/deploy-out/web/',
      negatable: false);
  parser.addFlag('verbose',
      help: 'show more logs when running unit tests in chrome',
      negatable: false);

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
    "windows": "chrome.exe"
  };

  String sep = Platform.pathSeparator;
  String os = Platform.operatingSystem;
  String path = "${sdkDir.path}${sep}..${sep}chromium${sep}${m[os]}";

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
    List paths = [
      r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
      r"C:\Program Files\Google\Chrome\Application\chrome.exe"
    ];

    for (String path in paths) {
      if (new File(path).existsSync()) {
        return path;
      }
    }
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

bool _canLocateSdk() {
  Directory dir = sdkDir;

  return dir != null && dir.existsSync() && joinDir(dir, ['bin']).existsSync();
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
