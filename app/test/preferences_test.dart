
library preferences_test;

import 'dart:async';

import 'package:unittest/unittest.dart';

import '../lib/preferences_chrome.dart';

main() {
  group('preferences.chrome', () {
    test('writeRead', () {
      chromePrefsLocal.setValue("foo1", "bar1");

      Future future = chromePrefsLocal.getValue("foo1").then((String val) {
        expect(val, equals("bar1"));
      });

      expect(future, completes);
     });

    test('writeReadSync', () {
      chromePrefsSync.setValue("foo2", "bar2");

      Future future = chromePrefsSync.getValue("foo2").then((String val) {
        expect(val, equals("bar2"));
      });

      expect(future, completes);
     });
  });

}
