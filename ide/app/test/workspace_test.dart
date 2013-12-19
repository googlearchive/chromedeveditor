// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.workspace_test;

import 'dart:async';

import 'package:chrome_gen/chrome_app.dart' as chrome;
import 'package:unittest/unittest.dart';

import 'files_mock.dart';
import '../lib/preferences.dart';
import '../lib/workspace.dart';

const _FILETEXT = 'This is sample text for mock file entry.';

defineTests() {
  group('workspace', () {

    test('create file and check contents', () {
      var workspace = new Workspace();
      MockFileSystem fs = new MockFileSystem();
      var fileEntry = fs.createFile('test.txt', contents: _FILETEXT);
      var fileResource = new File(workspace, fileEntry);
      expect(fileResource.name, fileEntry.name);
      expect(fileResource.path, '/test.txt');
      fileResource.getContents().then((string) {
        expect(string, _FILETEXT);
      });
    });

    test('restore entry', () {
      var workspace = new Workspace();
      MockFileSystem fs = new MockFileSystem();
      var fileEntry = fs.createFile('test.txt', contents: _FILETEXT);
      return workspace.link(fileEntry).then((Resource resource) {
        expect(resource.name, fileEntry.name);
        String token = resource.persistToToken();
        var restoredResource = workspace.restoreResource(token);
        expect(restoredResource, isNotNull);
        expect(restoredResource.name, resource.name);
        expect(restoredResource.path, resource.path);
      });
    });

    test('persist workspace roots', () {
      var prefs = new MapPreferencesStore();
      var workspace = new Workspace(prefs);
      return chrome.runtime.getPackageDirectoryEntry().then((dir) {
        return workspace.link(dir).then((Resource resource) {
          expect(resource, isNotNull);
          return workspace.save().then((_) {
            return prefs.getValue('workspace').then((String prefVal) {
              expect(prefVal, isNotNull);
              expect(prefVal.length, greaterThanOrEqualTo(10));
            });
          });
        });
      });
    });

    test('resource is hashable', () {
      var workspace = new Workspace();
      MockFileSystem fs = new MockFileSystem();
      var file1 = fs.createFile('test1.txt', contents: _FILETEXT);
      var file2 = fs.createFile('test2.txt', contents: _FILETEXT);
      return workspace.link(file1).then((Resource resource1) {
        return workspace.link(file2).then((Resource resource2) {
          Map m = {};
          m[resource1] = 'foo';
          m[resource2] = 'bar';
          expect(m[resource1], 'foo');
          expect(m[resource2], 'bar');
          var resource3 = workspace.getChild('test2.txt');
          m[resource3] = 'baz';
          expect(m[resource2], 'baz');
          expect(m[resource3], 'baz');
        });
      });
    });

    test('add file, check for resource add event', () {
      var workspace = new Workspace();
      MockFileSystem fs = new MockFileSystem();
      var fileEntry = fs.createFile('test.txt');

      Future future = workspace.onResourceChange.first.then((ResourceChangeEvent event) {
        ChangeDelta change = event.changes.single;
        expect(change.resource.name, fileEntry.name);
        expect(change.type, ResourceEventType.ADD);
      });

      workspace.link(fileEntry).then((resource) {
        expect(resource, isNotNull);
        expect(workspace.getChildren().contains(resource), isTrue);
        expect(workspace.getFiles().contains(resource), isTrue);
      });

      return future;
    });

    test('delete file, check for resource delete event', () {
      var workspace = new Workspace();
      MockFileSystem fs = new MockFileSystem();
      var fileEntry = fs.createFile('test.txt');
      var resource;

      workspace.link(fileEntry).then((res) {
        resource = res;
        expect(resource, isNotNull);
        expect(workspace.getChildren().contains(resource), isTrue);
        expect(workspace.getFiles().contains(resource), isTrue);
        resource.delete();
      });

      return workspace.onResourceChange.first.then((ResourceChangeEvent event) {
        ChangeDelta change = event.changes.single;
        expect(change.resource.name, fileEntry.name);
        expect(change.type, ResourceEventType.DELETE);
      });

    });

    test('add directory, check for resource add event', () {
      var workspace = new Workspace();
      MockFileSystem fs = new MockFileSystem();
      fs.createFile('/myProject/test.txt');
      fs.createFile('/myProject/test.html');
      fs.createFile('/myProject/test.dart');
      var dirEntry = fs.getEntry('myProject');

      Future future = workspace.onResourceChange.first.then((ResourceChangeEvent event) {
        ChangeDelta change = event.changes.single;
        expect(change.resource.name, dirEntry.name);
        expect(change.type, ResourceEventType.ADD);
      });

      workspace.link(dirEntry).then((project) {
        expect(project, isNotNull);
        expect(workspace.getChildren().contains(project), isTrue);
        expect(workspace.getProjects().contains(project), isTrue);
        var children = (project as Container).getChildren();
        expect(children.length, 3);
      });

      return future;
    });

    test('add directory with folders, check for resource add event', () {
      var workspace = new Workspace();
      MockFileSystem fs = new MockFileSystem();
      var projectDir = fs.createDirectory('myProject');
      fs.createFile('/myProject/index.html');
      fs.createFile('/myProject/myApp.dart');
      fs.createFile('/myProject/myApp.css');
      var dirEntry = fs.createDirectory('/myProject/myDir');
      fs.createFile('/myProject/myDir/test.txt');
      fs.createFile('/myProject/myDir/test.html');
      fs.createFile('/myProject/myDir/test.dart');

      Future future = workspace.onResourceChange.first.then((ResourceChangeEvent event) {
        ChangeDelta change = event.changes.single;
        expect(change.resource.name, projectDir.name);
        expect(change.type, ResourceEventType.ADD);
      });

      workspace.link(projectDir).then((project) {
        expect(project, isNotNull);
        expect(workspace.getChildren().contains(project), isTrue);
        expect(workspace.getProjects().contains(project), isTrue);
        var children = (project as Container).getChildren();
        expect(children.length, 4);
        for (var child in children){
          if (child is Folder) {
            expect((child as Folder).getChildren().length, 3);
          }
        }
      });
      return future;
    });

    test('refresh from filesystem', () {
      var workspace = new Workspace();
      MockFileSystem fs = new MockFileSystem();
      var projectDir = fs.createDirectory('myProject');
      fs.createFile('/myProject/index.html');
      fs.createFile('/myProject/myApp.dart');
      fs.createFile('/myProject/myApp.css');
      var dirEntry = fs.createDirectory('/myProject/myDir');
      fs.createFile('/myProject/myDir/test.txt');
      fs.createFile('/myProject/myDir/test.html');
      fs.createFile('/myProject/myDir/test.dart');

      return workspace.link(projectDir).then((project) {
        Folder dir = project.getChild('myDir');
        expect(project.getChildren().length, 4);
        expect(dir.getChildren().length, 3);
        fs.createFile('/myProject/myApp2.dart');
        fs.createFile('/myProject/myApp2.css');
        fs.removeFile('/myProject/myApp.css');
        fs.createFile('/myProject/myDir/test2.html');
        return workspace.refresh().then((e) {
          // Instance of /myProject/myDir might have changed because of
          // refresh(), then we request it again.
          // TODO(dvh): indentity of objects needs to be preserved by
          // workspace.refresh().
          dir = project.getChild('myDir');
          expect(project.getChildren().length, 5);
          expect(dir.getChildren().length, 4);
        });
      });
    });

    test("walk children performs a pre-order traversal", () {
      MockFileSystem fs = new MockFileSystem();
      Workspace workspace = new Workspace();
      var rootDir = fs.createDirectory('/root');
      fs.createDirectory('/root/folder1');
      fs.createDirectory('/root/folder2');
      fs.createDirectory('/root/folder1/folder3');
      fs.createFile('/root/folder1/file1');
      fs.createFile('/root/folder1/folder3/file2');
      fs.createFile('/root/folder2/file3');
      return workspace.link(rootDir).then((_) {
        Folder rootFolder = workspace.getChild('root');
        expect(rootFolder.traverse().map((f) => f.path),
               equals([ '/root',
                          '/root/folder1',
                            '/root/folder1/folder3',
                              '/root/folder1/folder3/file2',
                            '/root/folder1/file1',
                          '/root/folder2',
                            '/root/folder2/file3'
                      ]));
      });
    });
  });
}
