
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

import 'package:grinder/grinder.dart';

const _CHROME_PATH_ENV_KEY = 'CHROME_PATH';
const _MAC_CHROME_PATH = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

TestListener testListener;
Process chromeProcess;
int exitCode;

final int TEST_TIMEOUT = 10;

void main() {
  if (!new Directory('app').existsSync()) {
    throw 'This script must be run from the root of the project directory.';
  }

  // start a test listener
  TestListener.create().then((TestListener listener) {
    testListener = listener;

    startChrome('app');
  }).catchError(_fatalError);
}

String getChromePath() {
  // TODO: fix for cross platform

  // chromium/Chromium.app/Contents/MacOS/Chromium

  // TODO: check for an env override

  if (Platform.environment.containsKey(_CHROME_PATH_ENV_KEY)) {

  }

  String path = "${sdkDir.path}/../chromium/Chromium.app/Contents/MacOS/Chromium";

  if (FileSystemEntity.isFileSync(path)) {
    return new File(path).absolute.path;
  }

  throw 'unable to locate path to chrome';
}

void startChrome(String appPath) {
  // TODO: user-data-dir <temp dir>

  String path = new Directory(appPath).absolute.path;

  List<String> args = [
      '--no-default-browser-check',
      '--no-first-run',
      '--load-and-launch-app=${path}'
  ];

  if (Platform.isMacOS) {
    // TODO: does this work on OSes other then mac?
    args.add('--no-startup-window');
  }

  log("starting chrome...");
  log("${getChromePath()} ${args.join(' ')}");

  Process.start(getChromePath(), args, workingDirectory: appPath)
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

void _fatalError(e) {
  if (chromeProcess != null) {
    chromeProcess.kill();
  }

  log(e);

  exit(1);
}

void _testsFinished(int inExitCode) {
  if (exitCode != null) {
    return;
  }

  exitCode = inExitCode;

  testListener.close();

  // Give the chrome process a little time to shut down on its own.
  if (chromeProcess != null) {
    new Timer(new Duration(seconds: 2), () {
      if (chromeProcess != null) {
        chromeProcess.kill();
      }
      exit(exitCode);
    });
  } else {
    exit(exitCode);
  }
}

void _streamClosed() {
  // We exit here with an error. If we already recieved a "exit code: xxx", then
  // this error exit will be ignored. This covers the case where the stream is
  // closed by the test client before we're notified of the test results.
  _testsFinished(1);
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
