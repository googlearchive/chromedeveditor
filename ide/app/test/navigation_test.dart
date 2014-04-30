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
      expect(manager.canNavigate(), false);
      expect(manager.canNavigate(forward: false), false);

      manager.addLocation(_mockLocation());
      expect(manager.canNavigate(), false);
      expect(manager.canNavigate(forward: false), false);

      manager.addLocation(_mockLocation());
      expect(manager.canNavigate(), false);
      expect(manager.canNavigate(forward: false), true);
    });

    test('navigate', () {
      NavigationManager manager = new NavigationManager();
      Future f = manager.onNavigate.take(2).toList();
      manager.addLocation(_mockLocation());
      manager.addLocation(_mockLocation());
      expect(manager.canNavigate(forward: false), true);
      manager.navigate(forward: false);
      expect(manager.canNavigate(forward: false), false);
      manager.navigate(forward: true);
      expect(manager.canNavigate(forward: false), true);
      return f.then((List l) {
        expect(l.length, 2);
      });
    });

    test('location', () {
      NavigationManager manager = new NavigationManager();
      expect(manager.location, isNull);

      manager.addLocation(_mockLocation());
      expect(manager.canNavigate(forward: false), false);
      expect(manager.location, isNotNull);

      manager.addLocation(_mockLocation());
      expect(manager.canNavigate(), false);
      expect(manager.canNavigate(forward: false), true);
      expect(manager.location, isNotNull);
    });
  });
}

NavigationLocation _mockLocation() {
  return new NavigationLocation(null, new Span(0, 0));
}
