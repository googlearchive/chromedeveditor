// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.utils_tests;

import 'package:unittest/unittest.dart';

import '../lib/utils.dart';

main() {
  group('utils', () {
    test('i18n_found', () {
      expect(i18n('app_name'), equals('Spark'));
    });

    test('i18n_not_found', () {
      expect(i18n('not_found'), equals(''));
    });

    test('stripQuotes1', () {
      expect(stripQuotes('"a"'), equals('a'));
    });
    test('stripQuotes2', () {
      expect(stripQuotes('""'), equals(''));
    });
    test('stripQuotes3', () {
      expect(stripQuotes(''), equals(''));
    });
    test('stripQuotes4', () {
      expect(stripQuotes('"abc'), equals('"abc'));
    });
  });
}
