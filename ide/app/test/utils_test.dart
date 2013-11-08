// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.utils_tests;

import 'package:unittest/unittest.dart';

import '../lib/utils.dart';

main() {
  group('utils', () {
    test('i18n found', () {
      expect(i18n('app_name'), 'Spark');
    });

    test('i18n not found', () {
      expect(i18n('not_found'), '');
    });

    test('baseName', () {
      expect(baseName('foo'), 'foo');
      expect(baseName('foo/bar'), 'bar');
      expect(baseName('foo/bar/baz'), 'baz');
    });

    test('dirName', () {
      expect(dirName('foo'), '');
      expect(dirName('foo/bar'), 'foo');
      expect(dirName('foo/bar/baz'), 'foo/bar');
    });
  });
}
