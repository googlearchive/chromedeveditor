
library spark.filetypes.test;

import 'dart:async';

import 'package:unittest/unittest.dart';

import '../lib/filetypes.dart' as ftypes;
import '../lib/preferences.dart';
import '../lib/workspace.dart';
import 'files_mock.dart';

class MockFileTypePreferences implements ftypes.FileTypePreferences {
  final String fileType;
  MockFileTypePreferences(String this.fileType, [int this.custom = 0]);
  int custom = 0;
  Map toMap() => { 'custom' : custom };
}

MockFileTypePreferences _factory(String fileType, [Map map]) =>
    new MockFileTypePreferences(fileType, (map == null ? 0 : map['custom']));

defineTests() {
  group('filetypes', () {

    test('preference changed stream', () {
      var prefStore = new MapPreferencesStore();
      var fs = new MockFileSystem();
      var future = ftypes.onFileTypePreferenceChange(prefStore, _factory)
          .first.then((prefs) {
             expect(prefs.custom, 32);
          });

      prefStore.setJsonValue('fileTypePrefs/test1', { 'custom' : 32});

      return future;
    });

    test('global defaults loaded for new type', () {
      var prefStore = new MapPreferencesStore();
      var fs = new MockFileSystem();
      var testFile = fs.createFile('foo.test2');
      Workspace workspace = new Workspace();
      workspace.link(testFile);
      return ftypes.restorePreferences(prefStore, _factory, workspace.getChild('foo.test2'))
          .then((prefs) {
            expect(prefs.custom, 0);
          });
    });

    test('read/write preferences', () {
      var prefStore = new MapPreferencesStore();
      var fs = new MockFileSystem();
      var testFile = fs.createFile('foo.test3');
      Workspace workspace = new Workspace()
          ..link(testFile);
      var prefs = _factory('test3');
      prefs.custom = 50;
      return ftypes.persistPreferences(prefStore, prefs)
        .then((_) {
          return ftypes.restorePreferences(prefStore, _factory, workspace.getChild('foo.test3'))
              .then((prefs) {
                expect(prefs.custom, 50);
              });
        });
    });
  });
}