// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library preferences_test;

import 'dart:async';

import 'package:unittest/unittest.dart';

import '../lib/preferences.dart';

main() {
  group('preferences.chrome', () {
    test('writeRead', () {
      PreferenceStore localStorage = PreferenceStore.createLocal();
      localStorage.setValue("foo1", "bar1");

      return localStorage.getValue("foo1").then((String val) {
        expect(val, "bar1");
      });
    });

    test('writeReadSync', () {
      PreferenceStore syncStorage = PreferenceStore.createSync();
      syncStorage.setValue("foo2", "bar2");

      return syncStorage.getValue("foo2").then((String val) {
        expect(val, "bar2");
      });
    });

    test('write fires event', () {
      PreferenceStore storage = PreferenceStore.createLocal();

      Future future = storage.onPreferenceChange.take(1).toList().then((List<PreferenceEvent> events) {
        PreferenceEvent event = events.single;
        expect(event.key, "foo1");
        expect(event.value, "bar");
      });

      storage.setValue("foo1", "bar");

      return future;
    });
  });
}
