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
      var fileResource = new File(workspace, fileEntry, false);
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

    test('add file, check for resource add event', () {
      var workspace = new Workspace();
      MockFileSystem fs = new MockFileSystem();
      var fileEntry = fs.createFile('test.txt');

      Future future = workspace.onResourceChange.take(1).toList().then((List<ResourceChangeEvent> events) {
        ResourceChangeEvent event = events.single;
        expect(event.resource.name, fileEntry.name);
        expect(event.type, ResourceEventType.ADD);
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
        expect(event.resource.name, fileEntry.name);
        expect(event.type, ResourceEventType.DELETE);
      });

    });

    test('add directory, check for resource add event', () {
      var workspace = new Workspace();
      MockFileSystem fs = new MockFileSystem();
      fs.createFile('/myProject/test.txt');
      fs.createFile('/myProject/test.html');
      fs.createFile('/myProject/test.dart');
      var dirEntry = fs.getEntry('myProject');

      Future future = workspace.onResourceChange.take(1).toList().then((List<ResourceChangeEvent> events) {
        ResourceChangeEvent event = events.single;
        expect(event.resource.name, dirEntry.name);
        expect(event.type, ResourceEventType.ADD);
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

      Future future = workspace.onResourceChange.take(1).toList().then((List<ResourceChangeEvent> events) {
        ResourceChangeEvent event = events.single;
        expect(event.resource.name, projectDir.name);
        expect(event.type, ResourceEventType.ADD);
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
  });
}
