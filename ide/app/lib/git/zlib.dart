// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.zlib;

import 'dart:js' as js;

import 'package:chrome/src/common_exp.dart' as chrome;

/**
 * Encapsulates the result returned by js zlib library.
 */
class ZlibResult {
  final chrome.ArrayBuffer buffer;
  final int expectedLength;

  ZlibResult(this.buffer, [this.expectedLength]);

  List<int> get data => buffer.getBytes();
}

/**
 * Dart port of the javascript zlib library.
 */
class Zlib {
  static js.JsObject _zlib = js.context['Zlib'];

  /**
   * Inflates a zlib deflated byte stream.
   */
  static ZlibResult inflate(List<int> data, [int expectedLength]) {
    Map<String, int> options = {};
    if (expectedLength != null) {
      options['bufferSize'] = expectedLength;
    }
    js.JsObject inflater = new js.JsObject(
        _zlib['Inflate'], [_listToJs(data), options]);
    inflater['verify'] = true;
    js.JsObject buffer = inflater.callMethod('decompress');
    return new ZlibResult(chrome.ArrayBuffer.create(buffer), inflater['ip']);
  }

  /**
   * Deflates a byte stream.
   */
  static ZlibResult deflate(List<int> data) {
    js.JsObject deflater = new js.JsObject(_zlib['Deflate'], [_listToJs(data)]);
    js.JsObject buffer = deflater.callMethod('compress');
    return new ZlibResult(chrome.ArrayBuffer.create(buffer));
  }

  static dynamic _listToJs(List<int> data) => new js.JsArray.from(data);
}
