// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.utils;

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
 * Returns a minimal textual description of the stack trace. This converts
 * something like:
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

//#0      main.<anonymous closure>.<anonymous closure> (chrome-extension://ldgidbpjipgjnfimmhbmjbebaffmmdjc/test/utils_test.dart:35:9)
//#1      _run.<anonymous closure> (package:unittest/src/test_case.dart:110:30)
//#2      _Future._propagateToListeners.<anonymous closure> (dart:async/future_impl.dart:453)
//#3      _rootRun (dart:async/zone.dart:683)
//#4      _RootZone.run (dart:async/zone.dart:823)
//#5      _Future._propagateToListeners (dart:async/future_impl.dart:445)
//#6      _Future._complete (dart:async/future_impl.dart:303)
//#7      _Future._asyncComplete.<anonymous closure> (dart:async/future_impl.dart:354)
//#8      _asyncRunCallback (dart:async/schedule_microtask.dart:18)
//#9      _handleMutation (file:///Volumes/data/b/build/slave/dartium-mac-full-dev/build/src/dart/tools/dom/src/native_DOMImplementation.dart:612)

String  _minimizeLine(String line) {
  final String CHROME_EX = 'chrome-extension://';

  // match #, nums, ws, non-ws, ws, (, sdfsfsdf, )
  RegExp regex = new RegExp(r'#\d+\s+([\S ]+) \((\S+)\)');

  Match match = regex.firstMatch(line);

  if (match == null) {
    return line;
  } else {
    String method = match.group(1);
    method = method.replaceAll('<anonymous closure>', '<anon>');

    String location = match.group(2);

    // Strip off a leading chrome-extension://sdfsdfsdfsdf/...
    if (location.startsWith(CHROME_EX)) {
      location = location.substring(CHROME_EX.length);
      int index = location.indexOf('/');
      if (index != -1) {
        location = location.substring(index + 1);
      }
    }

    return '${method} ${location}';
  }
}
