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
      NavigationManager manager = new NavigationManager();
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
      NavigationManager manager = new NavigationManager();
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
      NavigationManager manager = new NavigationManager();
      expect(manager.location, isNull);

      manager.gotoLocation(_mockLocation());
      expect(manager.canGoBack(), false);
      expect(manager.location, isNotNull);

      manager.gotoLocation(_mockLocation());
      expect(manager.canGoForward(), false);
      expect(manager.canGoBack(), true);
      expect(manager.location, isNotNull);
    });
  });
}

NavigationLocation _mockLocation() {
  return new NavigationLocation(null, new Span(0, 0));
}
