
library spark.filetypes.test;

import 'dart:async';

import 'package:unittest/unittest.dart';

import '../lib/filetypes.dart';
import '../lib/preferences.dart';
import '../lib/workspace.dart';
import 'files_mock.dart';

defineTests() {
  group('filetypes', () {
    test("recognize inbuilt file types", () {
      var fs = new MockFileSystem();
      var workspace = new Workspace();
      
      var ftRegistry = new FileTypeRegistry();
      expect(ftRegistry.fileTypeOf(new File(workspace, fs.createFile('hello_world.css'), false)), 'css');
      expect(ftRegistry.fileTypeOf(new File(workspace, fs.createFile('hello_world.dart'), false)), 'dart');
      expect(ftRegistry.fileTypeOf(new File(workspace, fs.createFile('hello_world.htm'), false)), 'html');
      expect(ftRegistry.fileTypeOf(new File(workspace, fs.createFile('hello_world.js'), false)), 'js');
      expect(ftRegistry.fileTypeOf(new File(workspace, fs.createFile('hello_world.json'), false)), 'json');
      expect(ftRegistry.fileTypeOf(new File(workspace, fs.createFile('hello_world.md'), false)), 'md');
      expect(ftRegistry.fileTypeOf(new File(workspace, fs.createFile('hello_world.yaml'), false)), 'yaml');
      expect(ftRegistry.fileTypeOf(new File(workspace, fs.createFile('hello_world'), false)), 'unknown');
    });
    
    test("recognize custom file types", () {
      var fs = new MockFileSystem();
      var workspace = new Workspace();
      var ftRegistry = new FileTypeRegistry();
      ftRegistry.registerCustomType('foo', '.foo');
      expect(ftRegistry.fileTypeOf(new File(workspace, fs.createFile('hello_world.foo'), false)), 'foo');
    });
    
    test('preference changed stream', () {
      var prefStore = new MapPreferencesStore();
      var fs = new MockFileSystem();
      var ftRegistry = new FileTypeRegistry();
      ftRegistry.registerCustomType('test1', '.test1');
      var future = 
          ftRegistry.onFileTypePreferenceChange(prefStore, 'test1')
                    .first.then((prefs) {
                      expect(prefs.tabSize, 32);
                    });
      
      prefStore.setJsonValue('fileTypePrefs/test1', { 'useSoftTabs' : true, 'tabSize' : 32});
      
      return future;
    });
    
    test('global defaults loaded for new type', () {
      var prefStore = new MapPreferencesStore();
      var fs = new MockFileSystem();
      var ftRegistry = new FileTypeRegistry();
      ftRegistry.registerCustomType('test2', '.test2');
      return ftRegistry.restorePreferences(prefStore, 'test2')
          .then((prefs) {
            expect(prefs.useSoftTabs, true);
            expect(prefs.tabSize, 2);
          });
    });
    
    test('read/write preferences', () {
      var prefStore = new MapPreferencesStore();
      var fs = new MockFileSystem();
      var ftRegistry = new FileTypeRegistry();
      ftRegistry.registerCustomType('test3', '.test3');
      var prefs = ftRegistry.createPreferences('test3');
      prefs.tabSize = 50;
      return ftRegistry.persistPreferences(prefStore, prefs)
        .then((_) {
          return ftRegistry.restorePreferences(prefStore, 'test3')
              .then((prefs) {
                expect(prefs.tabSize, 50);
              });
        });
    });
  });
}