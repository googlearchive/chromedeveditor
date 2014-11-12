// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library preferences_test;

import 'dart:async';

//import 'package:chrome/chrome_app.dart' as chrome;
import 'package:unittest/unittest.dart';

import '../lib/preferences.dart';
import '../lib/utils.dart';

String editorConfigContent = """

# top-most EditorConfig file
root = true

# Unix-style newlines with a newline ending every file
[*]
end_of_line = lf
insert_final_newline = false

# 4 space indentation
[*.py]
indent_style = tab
indent_size = 4

# Tab indentation (no size specified)
[[!a-g]]
tab_width = 3
indent_size = tab

# Indentation override for all JS under lib directory
[lib/**.js]
indent_size = 5

# Matches the exact files either package.json or .travis.yml
[{package.json,.travis.yml}]
indent_style = space
indent_size = tab
""";

String editorConfigTooManyOptions = """
[*]
end_of_line = lf
insert_final_newline = false
should_not_be_here = true
""";

defineTests() {
  group('editorConfig', () {
    test('glob test - general', () {
      Glob glob = new Glob("a*/b**/d?");
      expect(glob.matchPath("alpha/bravo/charlie/delta"), Glob.PREFIX_MATCH);
      expect(glob.matchPath("alpha/bravo/charlie/d"), Glob.PREFIX_MATCH);
      expect(glob.matchPath("alpha/bravo/charlie/do"), Glob.COMPLETE_MATCH);
      expect(glob.matchPath("abc/do"), Glob.PREFIX_MATCH);
      expect(glob.matchPath("foo/bar"), Glob.NO_MATCH);
      expect(glob.matchPath(""), Glob.NO_MATCH);

      glob = new Glob("a*/b*");
      expect(glob.matchPath("abc/"), Glob.PREFIX_MATCH);
    });

    test('glob test - escaping', () {
      Glob glob = new Glob("a**/foo\\ bar");
      expect(glob.matchPath("aaa/bbb"), Glob.PREFIX_MATCH);
      expect(glob.matchPath("aaa/bbb/foo ba"), Glob.PREFIX_MATCH);
      expect(glob.matchPath("aaa/bbb/foo bar"), Glob.COMPLETE_MATCH);
      expect(glob.matchPath("aaa/bbb/foo barb"), Glob.PREFIX_MATCH);

      glob = new Glob("foo.dart");
      expect(glob.matchPath("foo.dart"), Glob.COMPLETE_MATCH);
      expect(glob.matchPath("foo!dart"), Glob.NO_MATCH);
    });

    test('EditorConfig - parsing', () {
      EditorConfig e = new EditorConfig.fromString(editorConfigContent);

      expect(e.root, true);
      EditorConfigSection section = e.sections["*"];
      expect(section.lineEnding, EditorConfigSection.ENDING_LF);
      expect(section.insertFinalNewline, false);
      section = e.sections["*.py"];
      expect(section.useSpaces, false);
      expect(section.indentSize, 4);
      section = e.sections["[!a-g]"];
      expect(section.tabWidth, 3);
      expect(section.indentSize, 3);
      section = e.sections["lib/**.js"];
      expect(section.tabWidth, 5);
      expect(section.indentSize, 5);
      section = e.sections["{package.json,.travis.yml}"];
      expect(section.useSpaces, true);
      expect(section.indentSize, 2);
      expect(() => new EditorConfig.fromString(editorConfigTooManyOptions),
          throws);
    });
  });

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
      // TODO(devoncarew): Disabled failing test as per #3179.
      if (isDart2js()) return new Future.value();

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
