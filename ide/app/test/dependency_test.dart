// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.dependency_test;

import 'package:unittest/unittest.dart';

import '../lib/dependency.dart';

defineTests() {
  group('dependency', () {
    test('retrieve dependency', () {
      Dependencies dependency = new Dependencies();
      expect(dependency[String], isNull);
      dependency[String] = 'foo';
      expect(dependency[String], isNotNull);
      expect(dependency[String], 'foo');
    });
  });
}
