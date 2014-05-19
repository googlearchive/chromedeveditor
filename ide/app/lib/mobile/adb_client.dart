// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A general library for ADB functionality.
 */
library spark.adb_client;

/**
 * An ADB device.
 */
class AdbDevice {
  /**
   * [id] can take on values like `emulator-5556` and `02b8372308e43795`.
   */
  final String id;
  final String description;

  AdbDevice(this.id, this.description);

  bool isOffline() => description == 'offline';
  bool isAttached() => description == 'device';

  bool isEmulator() => id.startsWith('emulator');

  String toString() => '[${id}, ${description}]';
}

class AdbApplication {
  /// Chrome browser.
  static AdbApplication CHROME = new AdbApplication(
      'com.android.chrome', 'com.google.android.apps.chrome.Main');

  /// Dart ContentShell.
  static AdbApplication CONTENT_SHELL = new AdbApplication(
      'org.chromium.content_shell_apk', '.ContentShellActivity');

  /// Chrome Apps Developer Tool (ADT).
  static AdbApplication CHROME_ADT = new AdbApplication(
      'org.chromium.ChromeADT', 'org.chromium.ChromeADT.ChromeADT');

  final String packageName;
  final String mainActivity;

  AdbApplication(this.packageName, this.mainActivity);

  /**
   * Return a string that can be passed into the activity manager to start the
   * application's process.
   */
  String getLaunchString() => '${packageName}/${mainActivity}';

  String toString() => packageName;
}

/**
 * An installed package on an Android device.
 */
class AdbPackage {
  /// The package name, e.g. `com.android.launcher`.
  final String name;

  /// The (optional) package file path, e.g. `/system/app/NetworkLocation.apk`.
  final String filePath;

  AdbPackage(this.name, [this.filePath]);

  bool isUser() => filePath != null && filePath.startsWith('/data/');
  bool isSystem() => filePath != null && filePath.startsWith('/system/');

  String toString() => name;
}
