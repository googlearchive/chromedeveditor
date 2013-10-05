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

    test('platform', () {
      expect(isLinux() || isMac() || isWin(), isTrue);
    });

    test('platform_one_set', () {
      int platformCount = 0;
      if (isLinux()) platformCount++;
      if (isMac()) platformCount++;
      if (isWin()) platformCount++;
      expect(platformCount, equals(1));
    });
  });
}
