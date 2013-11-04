// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.utils;

import 'dart:web_audio';

import 'package:chrome_gen/chrome_app.dart' as chrome_gen;

/**
 * This method is shorthand for [chrome.i18n.getMessage].
 */
String i18n(String messageId) {
  return chrome_gen.i18n.getMessage(messageId);
}

/**
 * Strip off one set of leading and trailing single or double quotes.
 */
String stripQuotes(String str) {
  if (str.length < 2) {
    return str;
  }

  if (str.startsWith("'") && str.endsWith("'")) {
    return str.substring(1, str.length - 1);
  }

  if (str.startsWith('"') && str.endsWith('"')) {
    return str.substring(1, str.length - 1);
  }

  return str;
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
