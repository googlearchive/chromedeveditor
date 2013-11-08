// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library zlib_test;

import 'dart:convert';
import 'dart:typed_data';

import 'package:unittest/unittest.dart';
import 'package:utf/utf.dart';

import '../lib/git/zlib.dart';

final String ZLIB_INPUT_STRING = "This is a test.";
final String ZLIB_DEFLATE_OUTPUT =
  "12015613194651300821924236481415120184233272346311218722219302251454341151536";

main() {
  group('git.zlib', () {
    test('inflate', () {

      // deflate a string.
      Uint8List buffer = new Uint8List.fromList(encodeUtf8(ZLIB_INPUT_STRING));
      ZlibResult deflated = Zlib.deflate(buffer);
      Uint8List buffer2 = new Uint8List.fromList(deflated.buffer.getBytes());

      // inflate the string back.
      ZlibResult result = Zlib.inflate(buffer2, null);

      String out = UTF8.decode(result.buffer.getBytes());
      return expect(out, ZLIB_INPUT_STRING);
    });

    test('deflate', () {
      Uint8List buffer = new Uint8List.fromList(encodeUtf8(ZLIB_INPUT_STRING));
      ZlibResult result = Zlib.deflate(buffer);

      List<int> bytes = result.buffer.getBytes();
      return expect(bytes.join(''), ZLIB_DEFLATE_OUTPUT);
    });
  });
}
