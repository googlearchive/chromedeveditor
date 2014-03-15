// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git_fast_sha_test;

import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:unittest/unittest.dart';

import '../../lib/git/fast_sha.dart';

defineTests() {
  group('git.fast_sha', () {
    test('test 0', ()      => _test(0));
    test('test 1', ()      => _test(1));
    test('test 10', ()     => _test(10));
    test('test 100', ()    => _test(100));
    test('test 1000', ()   => _test(1000));
    test('test 10000', ()  => _test(10000));
    test('test 100000', () => _test(100000));
  });
}

void _test(int size) {
  List data = _createData(size);

  FastSha sha = new FastSha();
  sha.add(data);
  List<int> fastShaResult = sha.close();

  crypto.SHA1 sha1 = new crypto.SHA1();
  sha1.add(data);
  List<int> cryptoResult = sha1.close();

  expect(fastShaResult, cryptoResult);
}

List _createData(int size) {
  Uint8List data = new Uint8List(size);
  for (int i = data.length - 1; i >= 0; i--) {
    data[i] = ((i * i) ^ i) & 0xFF;
  }
  return data;
}
