
library spark.filetypes.test;

import 'dart:async';

import 'package:unittest/unittest.dart';

import '../lib/filetypes.dart';
import '../lib/preferences.dart';
import '../lib/workspace.dart';
import 'files_mock.dart';

class MockFileTypePreferences implements FileTypePreferences {
  final String fileType;
  MockFileTypePreferences(String this.fileType, [int this.custom = 0]);
  int custom = 0;
  Map toMap() => { 'custom' : custom };
}

MockFileTypePreferences _factory(String fileType, [Map map]) =>
    new MockFileTypePreferences(fileType, (map == null ? 0 : map['custom']));

defineTests() {
  group('filetypes', () {
    test("recognize inbuilt file types", () {
      var fs = new MockFileSystem();
      var workspace = new Workspace();
      expect(fileTypeRegistry.fileTypeOf(new File(workspace, fs.createFile('hello_world.css'))), 'css');
      expect(fileTypeRegistry.fileTypeOf(new File(workspace, fs.createFile('hello_world.dart'))), 'dart');
      expect(fileTypeRegistry.fileTypeOf(new File(workspace, fs.createFile('hello_world.htm'))), 'html');
      expect(fileTypeRegistry.fileTypeOf(new File(workspace, fs.createFile('hello_world.js'))), 'js');
      expect(fileTypeRegistry.fileTypeOf(new File(workspace, fs.createFile('hello_world.json'))), 'json');
      expect(fileTypeRegistry.fileTypeOf(new File(workspace, fs.createFile('hello_world.md'))), 'md');
      expect(fileTypeRegistry.fileTypeOf(new File(workspace, fs.createFile('hello_world.yaml'))), 'yaml');
      expect(fileTypeRegistry.fileTypeOf(new File(workspace, fs.createFile('hello_world'))), 'text');
    });

    test("recognize custom file types", () {
      var fs = new MockFileSystem();
      var workspace = new Workspace();
      fileTypeRegistry.registerCustomType('foo', '.foo');
      expect(fileTypeRegistry.fileTypeOf(new File(workspace, fs.createFile('hello_world.foo'))), 'foo');
    });

    test('preference changed stream', () {
      var prefStore = new MapPreferencesStore();
      var fs = new MockFileSystem();
      fileTypeRegistry.registerCustomType('test1', '.test1');
      var future =
          fileTypeRegistry.onFileTypePreferenceChange(prefStore, _factory)
                    .first.then((prefs) {
                      expect(prefs.custom, 32);
                    });

      prefStore.setJsonValue('fileTypePrefs/test1', { 'custom' : 32});

      return future;
    });

    test('global defaults loaded for new type', () {
      var prefStore = new MapPreferencesStore();
      var fs = new MockFileSystem();
      fileTypeRegistry.registerCustomType('test2', '.test2');
      return fileTypeRegistry.restorePreferences(prefStore, _factory, 'test2')
          .then((prefs) {
            expect(prefs.custom, 0);
          });
    });

    test('read/write preferences', () {
      var prefStore = new MapPreferencesStore();
      var fs = new MockFileSystem();
      fileTypeRegistry.registerCustomType('test3', '.test3');
      var prefs = _factory('test3');
      prefs.custom = 50;
      return fileTypeRegistry.persistPreferences(prefStore, prefs)
        .then((_) {
          return fileTypeRegistry.restorePreferences(prefStore, _factory, 'test3')
              .then((prefs) {
                expect(prefs.custom, 50);
              });
        });
    });
  });
}