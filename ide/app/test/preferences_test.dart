// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library preferences_test;

import 'dart:async';

//import 'package:chrome/chrome_app.dart' as chrome;
import 'package:unittest/unittest.dart';

import '../lib/preferences.dart';

defineTests() {
  group('preferences.chrome', () {
    test('writeRead', () {
      localStore.setValue("foo1", "bar1");
      return localStore.getValue("foo1").then((String val) {
        expect(localStore.isDirty, true);
        expect(val, "bar1");
      });
    });

    test('writeReadSync', () {
      syncStore.setValue("foo2", "bar2");
      return syncStore.getValue("foo2").then((String val) {
        expect(val, "bar2");
      });
    });

    test('write fires event', () {
      Future future = localStore.onPreferenceChange.take(1).toList().then((List<PreferenceEvent> events) {
        PreferenceEvent event = events.single;
        expect(event.key, "foo1");
        expect(event.value, "bar");
      });

      localStore.setValue("foo1", "bar");

      return future;
    });

//    // TODO: we are not getting change events
//    test('mutation fires events', () {
//      Future future = localStore.onPreferenceChange.first.then((PreferenceEvent event) {
//        expect(event.key, "bar");
//        expect(event.value, "baz");
//      });
//
//      chrome.storage.local.set({'bar': 'baz'});
//
//      return future;
//    });

    test('map store gets dirty', () {
      MapPreferencesStore mapStore = new MapPreferencesStore();
      expect(mapStore.isDirty, false);
      return mapStore.setValue('foo', 'bar').then((_) {
        expect(mapStore.isDirty, true);
        return mapStore.getValue('foo').then((value) {
          expect(value, 'bar');
        });
      });
    });

    // Disabled this test, just so that running the tests doesn't clear out our
    // settings each time.
//    test('clearSync', () {
//      syncStore.setValue('foo3', 'bar3');
//      syncStore.setValue('foo4', 'bar4');
//      syncStore.setValue('foo5', 'bar5');
//      return syncStore.clear().then((_) {
//        return syncStore.getValue('foo3').then((value) {
//          expect(value, null);
//          return syncStore.getValue('foo4');
//        }).then((foo4_value) {
//          expect(foo4_value, null);
//          return syncStore.getValue('foo5');
//        }).then((foo5_value) {
//          expect(foo5_value, null);
//        });
//      });
//    });

    test('removeSync', () {
      MapPreferencesStore mapStore = new MapPreferencesStore();
      syncStore.setValue('foo6', 'bar6');
      return syncStore.getValue('foo6').then((String val) {
        expect(syncStore.isDirty, true);
        expect(val, 'bar6');
        return syncStore.removeValue(['foo6']);
      }).then((_) {
        return syncStore.getValue('foo6');
      }).then((value) {
        expect(value, null);
      });
    });
  });
}
