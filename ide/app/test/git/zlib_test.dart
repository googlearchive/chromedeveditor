// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library zlib_test;

import 'dart:convert';
import 'dart:typed_data';

import 'package:unittest/unittest.dart';
import 'package:utf/utf.dart';

import '../../lib/utils.dart';
import '../../lib/git/zlib.dart';

final String ZLIB_INPUT_STRING = "This is a test.";
final String ZLIB_DEFLATE_OUTPUT =
  "12015613194651300821924236481415120184233272346311218722219302251454341151536";

defineTests() {
  group('git.zlib', () {
    test('inflate', () {
      // deflate a string.
      Uint8List buffer = new Uint8List.fromList(encodeUtf8(ZLIB_INPUT_STRING));
      ZlibResult deflated = Zlib.deflate(buffer);
      Uint8List buffer2 = new Uint8List.fromList(deflated.data);

      // inflate the string back.
      ZlibResult result = Zlib.inflate(buffer2, null);

      String out = UTF8.decode(result.data);
      expect(out, ZLIB_INPUT_STRING);
    });

    test('deflate', () {
      Uint8List buffer = new Uint8List.fromList(encodeUtf8(ZLIB_INPUT_STRING));
      ZlibResult result = Zlib.deflate(buffer);

      List<int> bytes = result.data;
      expect(bytes.join(''), ZLIB_DEFLATE_OUTPUT);
    });

    // This test will time out if zlib deflate is very slow.
    test('speed test', () {
      PrintProfiler timer = new PrintProfiler('zlib test');

      StringBuffer buf = new StringBuffer();
      for (int i = 0; i < 10000; i++) {
        buf.writeln(ZLIB_INPUT_STRING);
      }

      timer.emit('create string');

      String str = buf.toString();
      Uint8List data = new Uint8List.fromList(UTF8.encoder.convert(str));
      timer.emit('encode');
      ZlibResult result = Zlib.deflate(data);
      timer.emit('deflate');
      result = Zlib.inflate(result.data, null);
      timer.emit('inflate');
      String decodedString = UTF8.decoder.convert(result.data);
      timer.emit('decode');
      expect(decodedString, str);
      timer.finish();
    });
  });
}
