// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.analytics_test;

import 'package:unittest/unittest.dart';

import '../lib/analytics.dart' as analytics;

main() {
  group('analytics', () {
    // This essentially tests whether the google-analytics-bundle.js codebase is
    // available.
    test('is available', () {
      expect(analytics.available, true);
    });
  });
}
