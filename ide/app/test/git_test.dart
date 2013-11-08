// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.git_test;

import 'package:unittest/unittest.dart';

import '../lib/git/git.dart';

main() {
  group('git', () {
    test('is available', () {
      expect(Git.available, true);
    });
  });
}
