// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.sdk;

import 'dart:async';
import 'dart:html' as html;

import 'package:chrome_gen/chrome_app.dart' as chrome_gen;

/**
 * Return the contents of the file at the given path. The path is relative to
 * the Chrome app's directory.
 */
Future<String> _getContent(String path) {
  return html.HttpRequest.getString(chrome_gen.runtime.getURL(path));
}

// TODO:
class DartSdk {
  final SdkDirectory libDirectory;

  // TODO:
  static bool get available => false;

  DartSdk(): libDirectory = new SdkDirectory._('sdk/lib');

  // TODO:
  String get version => 'dsfsdf';

}

abstract class SdkEntity {

}

class SdkFile {

}

class SdkDirectory {

}
