
library preferences_test;

import 'dart:async';

import 'package:unittest/unittest.dart';

import '../lib/preferences.dart';

main() {
  group('preferences.chrome', () {
    test('writeRead', () {

      PreferenceStore localStorage = PreferenceStore.createLocal();
      localStorage.setValue("foo1", "bar1");

      Future future = localStorage.getValue("foo1").then((String val) {
        expect(val, equals("bar1"));
      });

      expect(future, completes);
     });

    test('writeReadSync', () {

      PreferenceStore syncStorage = PreferenceStore.createSync();
      syncStorage.setValue("foo2", "bar2");

      Future future = syncStorage.getValue("foo2").then((String val) {
        expect(val, equals("bar2"));
      });

      expect(future, completes);
     });
  });

}
