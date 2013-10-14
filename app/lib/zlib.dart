// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.zlib;

import 'dart:js' as js;
import 'dart:typed_data';

import 'package:chrome_gen/src/common_exp.dart';

class ZlibResult {

  ArrayBuffer buffer;
  int expectedLength;

  ZlibResult(ArrayBuffer buffer) {
    this.buffer = buffer;
  }
}

class Zlib {

  static ZlibResult inflate(Uint8List data, int expectedLength) {

    Map<String, int> options = new Map<String, int>();
    if (expectedLength != null) {
      options['bufferSize'] = expectedLength;
    }
    js.JsObject inflate = new js.JsObject(js.context['Zlib']['Inflate'],
        [Zlib.uint8ListToJs(data), options]);
    inflate['verify'] = true;
    var buffer = inflate.callMethod('decompress', []);
    ZlibResult result = new ZlibResult(ArrayBuffer.create(buffer));
    result.expectedLength = inflate['ip'];
    return result;
  }

  static ZlibResult deflate(Uint8List data) {

    js.JsObject deflate = new js.JsObject(js.context['Zlib']['Deflate'],
        [Zlib.uint8ListToJs(data)]);
    var buffer = deflate.callMethod('compress', []);

    return new ZlibResult(ArrayBuffer.create(buffer));
  }

  static dynamic uint8ListToJs(Uint8List buffer) {
    return new js.JsObject(js.context['Uint8Array'],
        [js.jsify(buffer.toList(growable: true))]);
  }
}