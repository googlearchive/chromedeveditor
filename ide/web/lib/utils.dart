// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.utils;

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data' as typed_data;
import 'dart:web_audio';

import 'package:ace/ace.dart' as ace;
import 'package:chrome/chrome_app.dart' as chrome;
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

import 'exception.dart';

final NumberFormat _nf = new NumberFormat.decimalPattern();

final RegExp _imageFileTypes = new RegExp(r'\.(jpe?g|png|gif|ico)$',
    caseSensitive: false);

final RegExp _webFileTypes = new RegExp(r'\.(css|html?|xml)$',
    caseSensitive: false);

chrome.DirectoryEntry _packageDirectoryEntry;

/**
 * This method is shorthand for [chrome.i18n.getMessage].
 */
String i18n(String messageId) => chrome.i18n.getMessage(messageId);

/**
 * Return the Chrome App's directory. This utility method ensures that we only
 * make the `chrome.runtime.getPackageDirectoryEntry` once in the application's
 * lifetime.
 */
Future<chrome.DirectoryEntry> getPackageDirectoryEntry() {
  if (_packageDirectoryEntry != null) {
    return new Future.value(_packageDirectoryEntry);
  }

  return chrome.runtime.getPackageDirectoryEntry().then((dir) {
    _packageDirectoryEntry = dir;
    return dir;
  });
}

/**
 * Returns the given word with the first character capitalized.
 */
String capitalize(String s) {
  return s.isEmpty ? '' : (s[0].toUpperCase() + s.substring(1).toLowerCase());
}

/**
 * Returns a reasonable approximation of the given string converted into title
 * case. All words are capitalized with the exception of short ones.
 */
String toTitleCase(String s) {
  return s.split(' ').map((word) {
    if (word.length <= 2 || word == 'and' || word == 'the') {
      return word;
    } else {
      return capitalize(word);
    }
  }).join(' ');
}

/**
 * A helper to pass as the default to [collapseDups] and [trimEnds].
 */
bool _identity(dynamic a, dynamic b) => a == b;

/**
 * Removes adjacent duplicates from a container. Adjacent elements a and b are
 * considered duplicates if [test] returns true for them.
 */
List<dynamic> collapseDups(
    List<dynamic> input, [bool test(dynamic a, dynamic b) = _identity]) {
  List output = [];
  input.forEach((elt) {
    if (output.isEmpty || !test(elt, output.last)) {
      output.add(elt);
    }
  });
  return output;
}

/**
 * Removes one or more values from the beginning and end of a container.
 * A value is removed if [test] returns true for it.
 */
List<dynamic> trimEnds(List<dynamic> input, bool test(dynamic v)) {
  List<dynamic> output = input.skipWhile(test);
  while (output.isNotEmpty && test(output.last)) {
    output.removeLast();
  }
  return output;
}

AudioContext _ctx;

void beep() {
  if (_ctx == null) {
    _ctx = new AudioContext();
  }

  OscillatorNode osc = _ctx.createOscillator();

  osc.connectNode(_ctx.destination, 0, 0);
  osc.start(0);
  osc.stop(_ctx.currentTime + 0.1);
}

/**
 * Return whether the current runtime is dart2js (vs Dartium).
 */
bool isDart2js() => identical(1, 1.0);

/**
 * Return the contents of the file at the given path. The path is relative to
 * the Chrome app's directory.
 */
Future<List<int>> getAppContentsBinary(String path) {
  String url = chrome.runtime.getURL(path);

  return html.HttpRequest.request(url, responseType: 'arraybuffer').then((request) {
    var response = request.response;

    if (response is List) {
      return response;
    } else {
      typed_data.ByteBuffer buffer = request.response;
      return new typed_data.Uint8List.view(buffer);
    }
  });
}

/**
 * Return the contents of the file at the given path. The path is relative to
 * the Chrome app's directory.
 */
Future<String> getAppContents(String path) {
  return html.HttpRequest.getString(chrome.runtime.getURL(path))
      .catchError((e, s) =>
          throw "Couldn't download $path: error code ${e.target.status}");
}

/**
 * Returns true if the given [filename] matches common image file name patterns.
 */
bool isImageFilename(String filename) => _imageFileTypes.hasMatch(filename);

bool isHtmlFilename(String filename) =>
    filename.endsWith('.htm') || filename.endsWith('.html');

/**
 * Returns true if the given [filename] matches html/css/xml file types.
 */
bool isWebLikeFilename(String filename) => _webFileTypes.hasMatch(filename);

/**
 * Returns true if we can open the given file as text.
 */
bool isTextFilename(String name) {
  int index = name.indexOf('.');
  if (index == -1) return false;

  String ext = name.substring(index + 1);
  return ace.Mode.extensionMap.containsKey(ext);
}

/**
 * Returns a Future that completes after the next tick.
 */
Future nextTick() => new Future.delayed(Duration.ZERO);

html.DirectoryEntry _html5FSRoot;

/**
 * Returns the root directory of the application's persistent local storage.
 */
Future<html.DirectoryEntry> getLocalDataRoot() {
  // For now we request 100 MBs; would like this to be unlimited though.
  final int requestedSize = 100 * 1024 * 1024;

  if (_html5FSRoot != null) return new Future.value(_html5FSRoot);

  return html.window.requestFileSystem(
      requestedSize, persistent: true).then((html.FileSystem fs) {
    _html5FSRoot = fs.root;
    return _html5FSRoot;
  });
}

/**
 * Creates and returns a directory in persistent local storage. This can be used
 * to cache application data, e.g `getLocalDataDir('workspace')` or
 * `getLocalDataDir('pub')`.
 */
Future<html.DirectoryEntry> getLocalDataDir(String name) {
  return getLocalDataRoot().then((html.DirectoryEntry root) {
    return root.createDirectory(name, exclusive: false);
  });
}

/**
 * Return the most likely IP address for this machine.
 */
Future<String> getHostIP() {
  return chrome.system.network.getNetworkInterfaces().then(
      (List interfaces) {
    if (interfaces.isEmpty) {
      throw new SparkException("Local IP address not available");
    }

    // Use an IPv4 address if one is available.
    for (chrome.NetworkInterface net in interfaces) {
      if (net.prefixLength == 24) return net.address;
    }

    // Else return the first address.
    return interfaces.first.address;
  });
}

/**
 * A [Notifier] is used to present the user with a message.
 */
abstract class Notifier {
  void showMessage(String title, String message);

  Future showMessageAndWait(String title, String message);

  void showSuccessMessage(String message);

  Future<bool> askUserOkCancel(
      String message, {String okButtonLabel: 'OK', String title: ""});

  Future<chrome.ChromeFileEntry> chooseFileEntry();
}

/**
 * A [Notifier] implementation that just logs the given [title] and [message].
 */
class NullNotifier implements Notifier {
  void showMessage(String title, String message) {
    Logger.root.info('${title}:${message}');
  }

  Future showMessageAndWait(String title, String message) =>
      new Future.error("Not implemented");

  void showSuccessMessage(String message) { }

  Future<bool> askUserOkCancel(
      String message, {String okButtonLabel: 'OK', String title: ""}) {
    return new Future.error("Not implemented");
  }

  Future<chrome.ChromeFileEntry> chooseFileEntry() {
    return new Future.error("Not implemented");
  }
}

/**
 * A simple class to do `print()` profiling. It is used to profile a single
 * operation, and can time multiple sequential tasks within that operation. Each
 * call to [finishCurrentTask] reset the task timer, but does not effect the
 * operation timer. Call [finishProfiler] when the whole operation is complete.
 */
class PrintProfiler {
  final String name;
  final bool printToStdout;

  int _previousTaskTime = 0;
  Stopwatch _stopwatch = new Stopwatch();

  /**
   * Create a profiler to time a single operation (`name`).
   */
  PrintProfiler(this.name, {this.printToStdout: false}) {
    _stopwatch.start();
  }

  /**
   * The elapsed time for the current task.
   */
  int currentElapsedMs() => _stopwatch.elapsedMilliseconds;

  /**
   * Finish the current task and print out that task's elapsed time.
   */
  String finishCurrentTask(String taskName) {
    _stopwatch.stop();
    int ms = _stopwatch.elapsedMilliseconds;
    _previousTaskTime += ms;
    _stopwatch.reset();
    _stopwatch.start();
    String output = '${name}, ${taskName} ${_nf.format(ms)}ms';
    if (printToStdout) print(output);
    return output;
  }

  /**
   * Stop the timer, and print out the total time for the operation.
   */
  String finishProfiler() {
    _stopwatch.stop();
    String output = '${name} total: ${_nf.format(totalElapsedMs())}ms';
    if (printToStdout) print(output);
    return output;
  }

  /**
   * The elapsed time for the whole operation.
   */
  int totalElapsedMs() => _previousTaskTime + _stopwatch.elapsedMilliseconds;
}

/**
 * A utility class to make it easier to read a stream of lists of ints. Clients
 * of the API can instead read the data as a sequence of Futures, where they
 * request the number of bytes to read for each future.
 */
class StreamReader {
  final Stream<List<int>> stream;
  List<int> _buffer = [];
  // `_done` is true when there's no more data available to read.
  bool _done = false;
  Completer _completer;
  int _readLength;

  StreamReader(this.stream) {
    stream.listen((List<int> data) {
      _buffer.addAll(data);
      _checkListener();
    }, onDone: () {
      _done = true;
      _checkListener();
    });
  }

  /**
   * Return a Future which completes with the requested number of read bytes. If
   * `length` is given as `-1`, the Future will complete with all the remaining
   * bytes on the stream (see also, [readRemaining]).
   */
  Future<List<int>> read(int length) {
    _readLength = length;
    _completer = new Completer();
    Completer c = _completer;
    _checkListener();
    return c.future;
  }

  Future<List<int>> readRemaining() {
    return read(-1);
  }

  void _checkListener() {
    if (_completer == null) {
      return;
    } else if (_readLength != -1 && _buffer.length >= _readLength) {
      List<int> result = _buffer.sublist(0, _readLength);
      _buffer.removeRange(0, _readLength);
      _completer.complete(result);
      _completer = null;
    } else if (_done && _readLength == -1) {
      List<int> result = _buffer.sublist(0, _buffer.length);
      _buffer.clear();
      _completer.complete(result);
      _completer = null;
    } else if (_done) {
      _completer.completeError('eof');
      _completer = null;
    }
  }
}

/**
 * Returns a minimal textual description of the stack trace. I.e., instead of a
 * stack trace several thousand chars long, this tries to return one that can
 * meaningfully fit into several hundred chars. So, it converts something like:
 *
 *     "#0      newFile (chrome-extension://ldgidbpjipgjnfimmhbmjbebaffmmdjc/spark.dart:157:7)\n"
 *
 * into:
 *
 *     newFile spark.dart:157
 */
String minimizeStackTrace(StackTrace st) {
  if (st == null) return '';

  List lines = st.toString().trim().split('\n');
  lines = lines
      .map((l) => l.trim())
      .where((String line) => line.startsWith('at ') || line.startsWith('#'))
      .map((l) => _minimizeLine(l))
      .toList();

  // Remove all but one 'dart:' frame.
  int index = 0;
  while (index < lines.length) {
    String line = lines[index];

    if (line.startsWith('dart:') || line.startsWith('package:')) {
      index++;
    } else {
      break;
    }
  }

  if (index > 0) {
    lines = lines.sublist(index - 1);
  }

  return lines.join('#');
}

// A sample stack trace from Dartium:
//#0      main.<anonymous closure>.<anonymous closure> (chrome-extension://ldgidbpjipgjnfimmhbmjbebaffmmdjc/test/utils_test.dart:35:9)
//#1      _run.<anonymous closure> (package:unittest/src/test_case.dart:110:30)
//#2      _Future._propagateToListeners.<anonymous closure> (dart:async/future_impl.dart:453)
//#3      _rootRun (dart:async/zone.dart:683)
//#4      _RootZone.run (dart:async/zone.dart:823)
//#5      _Future._propagateToListeners (dart:async/future_impl.dart:445)

// Matches any string like "#, nums, ws, non-ws, 1 space, (non-ws)".
final RegExp DARTIUM_REGEX = new RegExp(r'#\d+\s+([\S ]+) \((\S+)\)');

// A sample stack trace from dart2js/chrome:
//  at Object.wrapException (chrome-extension://aadcannncidoiihkmomkaknobobnocln/spark.dart.precompiled.js:2646:13)
//  at UnknownJavaScriptObject.Interceptor.noSuchMethod$1 (chrome-extension://aadcannncidoiihkmomkaknobobnocln/spark.dart.precompiled.js:442:13)
//  at UnknownJavaScriptObject.Object.$index (chrome-extension://aadcannncidoiihkmomkaknobobnocln/spark.dart.precompiled.js:20740:17)
//  at Object.J.$index$asx (chrome-extension://aadcannncidoiihkmomkaknobobnocln/spark.dart.precompiled.js:157983:41)
//  at Object.CrEntry_CrEntry$fromProxy (chrome-extension://aadcannncidoiihkmomkaknobobnocln/spark.dart.precompiled.js:7029:14)
//  at Closure$0._asyncRunCallback [as call$0] (chrome-extension://ldgidbpjipgjnfimmhbmjbebaffmmdjc/spark.dart.precompiled.js:15853:18)

// Matches any string line "at, 1 space, non-ws, 1 space, (, non-ws, )".
final RegExp DART2JS_REGEX_1 = new RegExp(r'at (\S+) \((\S+)\)');
final RegExp DART2JS_REGEX_2 = new RegExp(r'at (\S+) (\[.+\]) \((\S+)\)');

String _minimizeLine(String line) {
  Function minimizePath = (String path) {
    // Replace a long deployed path with a shorter equivalent.
    return path.replaceAll('spark_polymer.html_bootstrap.dart.js', 'spark.js');
  };

  // Try and match a dartium stack trace first.
  Match match = DARTIUM_REGEX.firstMatch(line);

  if (match != null) {
    String method = match.group(1);
    method = method.replaceAll('<anonymous closure>', '<anon>');
    String location = _removeExtPrefix(match.group(2));
    return minimizePath('${method} ${location}');
  }

  // Try and match a dart2js stack trace.
  match = DART2JS_REGEX_1.firstMatch(line);

  if (match != null) {
    String method = match.group(1);
    String location = _removeExtPrefix(match.group(2));
    return minimizePath('${method} ${location}');
  }

  // Try and match an alternative dart2js stack trace format.
  match = DART2JS_REGEX_2.firstMatch(line);

  if (match != null) {
    String method = match.group(1);
    String location = _removeExtPrefix(match.group(3));
    return minimizePath('${method} ${location}');
  }

  return line;
}

/**
 * Strip off a leading chrome-extension://sdfsdfsdfsdf/...
 */
String _removeExtPrefix(String str) {
  return str.replaceFirst(new RegExp("chrome-extension://[a-z0-9]+/"), "");
}

// String _platform() {
//   String str = html.window.navigator.platform;
//   return (str != null) ? str.toLowerCase() : '';
// }

class FutureHelper {
  /**
   * Perform an async operation for each element of the iterable, in turn. It
   * refreshes the UI after each iteraton.
   *
   * Runs [f] for each element in [input] in order, moving to the next element
   * only when the [Future] returned by [f] completes. Returns a [Future] that
   * completes when all elements have been processed.
   *
   * The return values of all [Future]s are discarded. Any errors will cause the
   * iteration to stop and will be piped through the returned [Future].
   */
  static Future forEachNonBlockingUI(Iterable input, Future f(element)) {
    Completer doneSignal = new Completer();
    Iterator iterator = input.iterator;
    void nextElement(_) {
      if (iterator.moveNext()) {
        nextTick().then((_) {
          try {
            f(iterator.current)
             .then(nextElement,  onError: (e) => doneSignal.completeError(e));
          } catch (e) {
            doneSignal.completeError(e);
          }
        });
      } else {
        doneSignal.complete(null);
      }
    }
    nextElement(null);
    return doneSignal.future;
  }
}

/**
 * Pretty print Json text.
 *
 * Usage:
 *     String str = new JsonPrinter().print(jsonObject);
 */
class JsonPrinter {
  String _in = '';

  JsonPrinter();

  /**
   * Given a structured, json-like object, print it to a well-formatted, valid
   * json string.
   */
  String print(dynamic json) {
    return _print(json) + '\n';
  }

  String _print(var obj) {
    if (obj is List) {
      return _printList(obj);
    } else if (obj is Map) {
      return _printMap(obj);
    } else if (obj is String) {
      return '"${obj}"';
    } else {
      return '${obj}';
    }
  }

  String _printList(List list) {
    return "[${_indent()}${list.map(_print).join(',${_newLine}')}${_unIndent()}]";
  }

  String _printMap(Map map) {
    return "{${_indent()}${map.keys.map((key) {
      return '"${key}": ${_print(map[key])}';
    }).join(',${_newLine}')}${_unIndent()}}";
  }

  String get _newLine => '\n${_in}';

  String _indent() {
    _in += '  ';
    return '\n${_in}';
  }

  String _unIndent() {
    _in = _in.substring(2);
    return '\n${_in}';
  }
}

/**
 * Downloads a remote file at [url]. Returns the file's text. If file doesn't
 * exist, returns an empty string.
 */
Future<String> downloadFileViaXhr(
    String url,
    [String mimeType = 'text\/plain; charset=x-user-defined']) {
  final completer = new Completer();
  final request = new html.HttpRequest();

  request.open('GET', url);
  request.overrideMimeType(mimeType);
  request.onLoadEnd.listen((event) {
    if (request.status == 200) {
      completer.complete(request.responseText);
    } else if (request.status == 403) {
      // Access forbidden. It's possible that we've hit a rate limit.
      final String rateLimitRemaining =
          request.responseHeaders['x-ratelimit-remaining'];
      if (rateLimitRemaining == '0') {
        String rateLimitReset = request.responseHeaders['x-ratelimit-reset'];
        if (rateLimitReset != null) {
          final int msSinceEpoch = int.parse(rateLimitReset) * 1000;
          rateLimitReset = new DateTime.fromMillisecondsSinceEpoch(
              msSinceEpoch, isUtc: true).toLocal().toString();
        } else {
          rateLimitReset = "unknown time";
        }
        completer.completeError(
            "Reached the access rate limit when requesting '$url': "
            "the limit will reset at $rateLimitReset");
      } else {
        completer.completeError("Access to '$url' is (temporarily) forbidden");
      }
    } else if (request.status == 404) {
      // Remote file doesn't exist.
      completer.complete('');
    } else {
      completer.completeError(
          "Failed to download '$url': ${request.statusText}");
    }
  });
  request.send();

  return completer.future;
}

Future<String> getRedirectedUrlViaXhr(String url) {
  final completer = new Completer();
  final request = new html.HttpRequest();

  request.open('HEAD', url);
  request.onLoadEnd.listen((event) {
    completer.complete(request.responseUrl);
  });
  request.send();

  return completer.future;
}

class DelayedTimer {
  Timer _timer;
  final Duration _delay;
  final Function _fn;

  DelayedTimer(this._fn, this._delay);

  void start() {
    if (_timer != null) _timer.cancel();
    _timer = new Timer(_delay, _fn);
  }
}
