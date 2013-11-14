// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.git_utils_test;

import 'package:unittest/unittest.dart';

import '../lib/git/git_utils.dart';

final String SHA_STRING_TEST = "6a21325b42661e4ae5bc659a1cb66a21938d784f";
final List<int> SHA_BYTES_TEST =
    [106,33,50,91,66,102,30,74,229,188,101,154,28,182,106,33,147,141,120,79];

main() {
  group('git_utils', () {
    test('shaToBytes', () {
      expect(shaToBytes(SHA_STRING_TEST), SHA_BYTES_TEST);
    });

    test('bytesToSha', () {
      expect(shaBytesToString(SHA_BYTES_TEST), SHA_STRING_TEST);
    });
  });
}
