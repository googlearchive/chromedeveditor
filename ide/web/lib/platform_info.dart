// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.platform_info;

import 'dart:async';
import 'dart:html';

import 'package:chrome/chrome_app.dart' as chrome;

class PlatformInfo {
  // Matches any char, Chrome/, numbers, any char.
  static final RegExp _CHROME_VERSION_REGEX = new RegExp(r'.*Chrome/(\d+).*');

  static PlatformInfo _instance;

  static int _chromeVersion;

  /**
   * This method needs to be invoked before accessing any of the static getters,
   * probably early during app startup.
   */
  static Future init() {
    return chrome.runtime.getPlatformInfo().then((chrome.PlatformInfo info) {
      _instance = new PlatformInfo._(info.os, info.arch, info.nacl_arch);
    });
  }

  /**
   * The operating system chrome is running on. One of: "mac", "win", "android",
   * "cros", "linux", "openbsd".
   */
  static String get os => _instance._os;

  static bool get isWin => _instance._os == 'win';
  static bool get isMac => _instance._os == 'mac';
  static bool get isCros => _instance._os == 'cros';
  static bool get isLinux => _instance._os == 'linux';
  static bool get isAndroid => _instance._os == 'android';

  /**
   * The machine's processor architecture. One of: "arm", "x86-32", "x86-64".
   */
  static String get arch => _instance._arch;

  /**
   * The native client architecture. This may be different from arch on some
   * platforms. One of: "arm", "x86-32", "x86-64".
   */
  static String get naclArch => _instance._naclArch;

  /**
   * Returns the major Chrome version, i.e., 37, 38, 39, ...
   */
  static int get chromeVersion {
    if (_chromeVersion == null) {
      // 5.0 (Macintosh; ... like Gecko) Chrome/37.0.2062.76 (Dart) Safari/537.36
      String versionStr = window.navigator.appVersion;
      try {
        Match match = _CHROME_VERSION_REGEX.firstMatch(versionStr);
        _chromeVersion = int.parse(match.group(1));
      } catch (e) {
        _chromeVersion = 0;
      }
    }

    return _chromeVersion;
  }

  final String _os;
  final String _arch;
  final String _naclArch;

  PlatformInfo._(this._os, this._arch, this._naclArch);
}
