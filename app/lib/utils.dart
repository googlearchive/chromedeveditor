
library spark.utils;

import 'dart:html';
import 'dart:web_audio';

import 'package:chrome/app.dart' as chrome;

/**
 * This method is shorthand for [chrome.i18n.getMessage].
 */
String i18n(String messageId) {
  return chrome.i18n.getMessage(messageId);
}

bool isLinux() {
  return _platform().indexOf('linux') != -1;
}

bool isMac() {
  return _platform().indexOf('mac') != -1;
}

bool isWin() {
  return _platform().indexOf('win') != -1;
}

String _platform() {
  String str = window.navigator.platform;

  return (str != null) ? str.toLowerCase() : '';
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
