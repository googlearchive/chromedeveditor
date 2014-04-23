// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.platform_info;

import 'dart:async';

import 'package:chrome/chrome_app.dart' as chrome;

class PlatformInfo {
  static PlatformInfo _instance;

  /**
   * This methof needs to be invoked before accessing any of the static getters,
   * probably early during app startup.
   */
  static Future init() {
    return chrome.runtime.getPlatformInfo().then((Map map) {
      _instance = new PlatformInfo._(map);
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

  final String _os;
  final String _arch;
  final String _naclArch;

  PlatformInfo._(Map m) :
      _os = m['os'], _arch = m['arch'], _naclArch = m['nacl_arch'];
}
