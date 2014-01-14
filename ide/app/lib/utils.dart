// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.utils;

import 'dart:web_audio';

import 'package:chrome/chrome_app.dart' as chrome;

/**
 * This method is shorthand for [chrome.i18n.getMessage].
 */
String i18n(String messageId) => chrome.i18n.getMessage(messageId);

String capitalize(String s) {
  return s.isEmpty ? '' : (s[0].toUpperCase() + s.substring(1));
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
 * A simple class to do `print()` profiling. It is used to profile a single
 * operation, and can time multiple sequential tasks within that operation.
 * Each call to [emit] reset the task timer, but does not effect the operation
 * timer. Call [finish] when the whole operation is complete.
 */
class PrintProfiler {
  final String name;
  final bool quiet;

  int _previousTaskTime = 0;
  Stopwatch _stopwatch = new Stopwatch();

  /**
   * Create a profiler to time a single operation (`name`).
   */
  PrintProfiler(this.name, {this.quiet: false}) {
    _stopwatch.start();
  }

  /**
   * The elapsed time for the current task.
   */
  int currentElapsedMs() => _stopwatch.elapsedMilliseconds;

  /**
   * Finish the current task and print out that task's elapsed time.
   */
  void emit(String taskName) {
    _stopwatch.stop();
    int ms = _stopwatch.elapsedMilliseconds;
    if (!quiet) {
      print('${name}, ${taskName} ${ms / 1000}s');
    }
    _previousTaskTime += ms;
    _stopwatch.reset();
    _stopwatch.start();
  }

  /**
   * Stop the timer, and print out the total time for the operation.
   */
  void finish() {
    _stopwatch.stop();
    if (!quiet) {
      print('${name} total: ${totalElapsedMs() / 1000}s');
    }
  }

  /**
   * The elapsed time for the whole operation.
   */
  int totalElapsedMs() => _previousTaskTime + _stopwatch.elapsedMilliseconds;
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
  lines = lines.map((l) => _minimizeLine(l.trim())).toList();

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

  return lines.join('\n');
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
  // Try and match a dartium stack trace first.
  Match match = DARTIUM_REGEX.firstMatch(line);

  if (match != null) {
    String method = match.group(1);
    method = method.replaceAll('<anonymous closure>', '<anon>');
    String location = _removeExtPrefix(match.group(2));
    return '${method} ${location}';
  }

  // Try and match a dart2js stack trace.
  match = DART2JS_REGEX_1.firstMatch(line);

  if (match != null) {
    String method = match.group(1);
    String location = _removeExtPrefix(match.group(2));
    return '${method} ${location}';
  }

  // Try and match an alternative dart2js stack trace format.
  match = DART2JS_REGEX_2.firstMatch(line);

  if (match != null) {
    String method = match.group(1);
    String location = _removeExtPrefix(match.group(3));
    return '${method} ${location}';
  }

  return line;
}

/**
 * Strip off a leading chrome-extension://sdfsdfsdfsdf/...
 */
String _removeExtPrefix(String str) {
  return str.replaceFirst(new RegExp("chrome-extension://[a-z0-9]+/"), "");
}
