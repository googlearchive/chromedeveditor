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

    // Ensure that the analytics methods work reasonably well and don't throw.
    // Use a fake app name and tracking id (UA-xxx).
    test('create service, create tracker', () {
      return analytics.getService('SparkTest').then((analytics.GoogleAnalytics service) {
        expect(service, isNotNull);
        expect(service.getConfig(), isNotNull);
        // just assert that we can call isTrackingPermitted()
        expect(service.getConfig().isTrackingPermitted(), isNotNull);
        analytics.Tracker tracker = service.getTracker('UA-0');
        expect(tracker, isNotNull);
        // assert that we can call sendAppView
        tracker.sendAppView('/testing');
      });
    });
  });
}
