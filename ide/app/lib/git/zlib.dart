// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.zlib;

import 'dart:typed_data';

import 'package:archive/archive.dart' as archive;

/**
 * The zlib result.
 */
class ZlibResult {
  final List<int> data;
  final int readLength;

  ZlibResult(this.data, [this.readLength]);
}

/**
 * Zlib inflate and deflate.
 */
class Zlib {
  /**
   * Inflates a zlib deflated byte stream.
   */
  static ZlibResult inflate(List<int> data, {int offset: 0, int expectedLength}) {
    archive.InputStream stream = new archive.InputStream(data, start: offset);
    archive.ZLibDecoder decoder = new archive.ZLibDecoder();

    List<int> bytes = decoder.decodeBuffer(stream, verify: false);

    return new ZlibResult(bytes, stream.position);
  }

  /**
   * Deflates a byte stream.
   */
  static Uint8List deflate(List<int> data) {
    archive.ZLibEncoder encoder = new archive.ZLibEncoder();
    // Note: ZLibEncoder always returns a `Uint8List` list.
    return encoder.encode(data);
  }
}
