// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.navigation_test;

import 'dart:async';

import 'package:unittest/unittest.dart';

import '../lib/navigation.dart';

defineTests() {
  group('navigation', () {
    test('canNavigate', () {
      NavigationManager manager =
          new NavigationManager(new MockNavigationLocationProvider());
      expect(manager.canGoForward(), false);
      expect(manager.canGoBack(), false);

      manager.gotoLocation(_mockLocation());
      expect(manager.canGoForward(), false);
      expect(manager.canGoBack(), false);

      manager.gotoLocation(_mockLocation());
      expect(manager.canGoForward(), false);
      expect(manager.canGoBack(), true);
    });

    test('navigate', () {
      NavigationManager manager =
          new NavigationManager(new MockNavigationLocationProvider());
      Future f = manager.onNavigate.take(2).toList();
      manager.gotoLocation(_mockLocation());
      manager.gotoLocation(_mockLocation());
      expect(manager.canGoBack(), true);
      manager.goBack();
      expect(manager.canGoBack(), false);
      manager.goForward();
      expect(manager.canGoBack(), true);
      return f.then((List l) {
        expect(l.length, 2);
      });
    });

    test('location', () {
      NavigationManager manager =
          new NavigationManager(new MockNavigationLocationProvider());
      expect(manager.backLocation, isNull);

      manager.gotoLocation(_mockLocation());
      expect(manager.canGoBack(), false);
      expect(manager.backLocation, isNull);
      expect(manager.currentLocation, isNotNull);
      expect(manager.forwardLocation, isNull);

      manager.gotoLocation(_mockLocation());
      expect(manager.canGoForward(), false);
      expect(manager.canGoBack(), true);
      expect(manager.backLocation, isNotNull);
      expect(manager.currentLocation, isNotNull);
      expect(manager.forwardLocation, isNull);

      manager.goBack();
      expect(manager.backLocation, isNull);
      expect(manager.currentLocation, isNotNull);
      expect(manager.forwardLocation, isNotNull);
    });
  });
}

int navigationOffset = 0;

NavigationLocation _mockLocation() {
  return new NavigationLocation(null, new Span(navigationOffset++, 0));
}

class MockNavigationLocationProvider implements NavigationLocationProvider {
  bool first = true;

  NavigationLocation get navigationLocation {
    if (first) {
      first = false;
      return null;
    } else {
      return _mockLocation();
    }
  }
}
