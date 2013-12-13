// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.workspace_test;

import 'dart:async';

import 'package:unittest/unittest.dart';

import 'files_mock.dart';
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
  });
}
