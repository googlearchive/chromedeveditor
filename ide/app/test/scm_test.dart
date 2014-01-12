// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library scm_test;

import 'package:unittest/unittest.dart';

import '../lib/scm.dart' as scm;

defineTests() {
  group('scm', () {
    test('getProviders', () {
      expect(scm.getProviders().length, 1);
    });

    test('get git provider', () {
      expect(scm.getProviderType('grit'), isNull);
      expect(scm.getProviderType('git'), isNotNull);
      expect(scm.getProviderType('git').id, 'git');
    });
  });
}
