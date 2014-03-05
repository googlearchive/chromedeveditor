// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.zlib;

import 'dart:js' as js;

import 'package:archive/archive.dart' as archive;
import 'package:chrome/src/common_exp.dart' as chrome;

/**
 * Encapsulates the result returned by js zlib library.
 */
class ZlibResult {
  final List<int> data;
  final int readLength;

  ZlibResult(this.data, [this.readLength]);
}

/**
 * Dart port of the javascript zlib library.
 */
class Zlib {
  static js.JsObject _zlib = js.context['Zlib'];

  /**
   * Inflates a zlib deflated byte stream.
   */
  static ZlibResult inflate(List<int> data, {int offset: 0, int expectedLength}) {
    // We assume that the compressed string will not be greater by 1000 in
    // length to the uncompressed string.
    // This has a very significant impact on performance.
    if (expectedLength != null) {
      int end =  expectedLength + offset + 1000;
      if (end > data.length) end = data.length;
      data = data.sublist(offset, end);
    }

    Map<String, int> options = {};
    if (expectedLength != null) {
      options['bufferSize'] = expectedLength;
    }
    js.JsObject inflater = new js.JsObject(_zlib['Inflate'], [_listToJs(data), options]);
    inflater['verify'] = true;
    var buffer = inflater.callMethod('decompress');
    return new ZlibResult(new chrome.ArrayBuffer.fromProxy(buffer).getBytes(),
        inflater['ip']);

//    archive.InputStream stream = new archive.InputStream(data, start: offset);
//    archive.Inflate inflater = new archive.Inflate.buffer(stream); //, expectedLength);
//
//    return new ZlibResult(inflater.getBytes(), stream.position);
  }

  /**
   * Deflates a byte stream.
   */
  static ZlibResult deflate(List<int> data) {
    js.JsObject deflater = new js.JsObject(_zlib['Deflate'], [_listToJs(data)]);
    // TODO: This should be a JsObject, but Dartium returns an Uint8List.
    var buffer = deflater.callMethod('compress');
    return new ZlibResult(chrome.ArrayBuffer.create(buffer).getBytes());
  }

  static dynamic _listToJs(List<int> data) => new js.JsArray.from(data);
}
