// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.utils;

import 'dart:html' show document;
import 'dart:web_audio';

import 'package:chrome_gen/chrome_app.dart' as chrome;

/**
 * This method is shorthand for [chrome.i18n.getMessage].
 */
String i18n(String messageId) {
  return chrome.i18n.getMessage(messageId);
}

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
 * Returns the path before the last separtor.
 */
String dirName(String path) {
  int index = path.lastIndexOf('/');
  return index == -1 ? null : path.substring(0, index);
}

/**
 * Returns the path after the last separtor.
 */
String baseName(String path) {
  int index = path.lastIndexOf('/');
  return index == -1 ? path : path.substring(index + 1);
}

/**
 * Return whether the current runtime is dart2js (vs Dartium).
 */
bool isDart2js() {
  return document.getElementsByTagName("script").where(
      (s) => s.src.endsWith(".precompiled.js")).isNotEmpty;
}

/**
 * Returns a minimal textual description of the stack trace. I.e., instead of a
 * stack trace several thousand chars long, this trie to return one that can
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

// match #, nums, ws, non-ws, 1 space, (, non-ws, )
final RegExp DARTIUM_REGEX = new RegExp(r'#\d+\s+([\S ]+) \((\S+)\)');

// A sample stack trace from dart2js/chrome:
//    chrome-extension://ldgidbpjipgjnfimmhbmjbebaffmmdjc/spark.dart.precompiled.js 2646:13    Object.wrapException
//    chrome-extension://ldgidbpjipgjnfimmhbmjbebaffmmdjc/spark.dart.precompiled.js 105756:13  DefaultFailureHandler.fail$1
//    chrome-extension://ldgidbpjipgjnfimmhbmjbebaffmmdjc/spark.dart.precompiled.js 105201:20  Object.expect
//    chrome-extension://ldgidbpjipgjnfimmhbmjbebaffmmdjc/spark.dart.precompiled.js 125728:9   main__closure11.call$0

// match non-ws, 1 space, num, :, num, ws, non-ws
final RegExp DART2JS_REGEX = new RegExp(r'(\S+) (\d+:\d+)\s+(\S+)');

String  _minimizeLine(String line) {
  // Try and match a dartium stack trace first.
  Match match = DARTIUM_REGEX.firstMatch(line);

  if (match != null) {
    String method = match.group(1);
    method = method.replaceAll('<anonymous closure>', '<anon>');
    String location = _removeExtPrefix(match.group(2));
    return '${method} ${location}';
  }

  // Then try a dart2js stack trace.
  match = DART2JS_REGEX.firstMatch(line);

  if (match != null) {
    String location = _removeExtPrefix(match.group(1));
    String line = match.group(2);
    String method = match.group(3);
    return '${method} ${location}:${line}';
  }

  return line;
}

/**
 * Strip off a leading chrome-extension://sdfsdfsdfsdf/...
 */
String _removeExtPrefix(String str) {
  final String CHROME_EX = 'chrome-extension://';

  if (str.startsWith(CHROME_EX)) {
    str = str.substring(CHROME_EX.length);
    int index = str.indexOf('/');
    if (index != -1) {
      str = str.substring(index + 1);
    }
  }

  return str;
}
