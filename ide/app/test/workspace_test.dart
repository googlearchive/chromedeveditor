// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.workspace_test;

import 'dart:async';

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:unittest/unittest.dart';

import 'files_mock.dart';
import '../lib/preferences.dart';
import '../lib/utils.dart';
import '../lib/workspace.dart' as ws;

const _FILETEXT = 'This is sample text for mock file entry.';

defineTests() {
  group('workspace', () {

    test('create file and check contents', () {
      var workspace = new ws.Workspace();
      MockFileSystem fs = new MockFileSystem();
      var fileEntry = fs.createFile('test.txt', contents: _FILETEXT);
      var fileResource = new ws.File(workspace, fileEntry);
      expect(fileResource.name, fileEntry.name);
      expect(fileResource.path, '/test.txt');
      fileResource.getContents().then((string) {
        expect(string, _FILETEXT);
      });
    });

    test('restore entry', () {
      var workspace = new ws.Workspace();
      MockFileSystem fs = new MockFileSystem();
      var fileEntry = fs.createFile('test.txt', contents: _FILETEXT);
      return workspace.link(fileEntry).then((ws.Resource resource) {
        expect(resource.name, fileEntry.name);
        String token = resource.persistToToken();
        var restoredResource = workspace.restoreResource(token);
        expect(restoredResource, isNotNull);
        expect(restoredResource.name, resource.name);
        expect(restoredResource.path, resource.path);
      });
    });

    test('persist workspace roots', () {
      // Disabled because it doesn't work on Chrome < 31.
      if (isDart2js()) return null;

      var prefs = new MapPreferencesStore();
      var workspace = new ws.Workspace(prefs);
      return chrome.runtime.getPackageDirectoryEntry().then((dir) {
        return workspace.link(dir).then((ws.Resource resource) {
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
      var workspace = new ws.Workspace();
      MockFileSystem fs = new MockFileSystem();
      var file1 = fs.createFile('test1.txt', contents: _FILETEXT);
      var file2 = fs.createFile('test2.txt', contents: _FILETEXT);
      return workspace.link(file1).then((ws.Resource resource1) {
        return workspace.link(file2).then((ws.Resource resource2) {
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
      var workspace = new ws.Workspace();
      MockFileSystem fs = new MockFileSystem();
      var fileEntry = fs.createFile('test.txt');

      Future future = workspace.onResourceChange.first.then((ws.ResourceChangeEvent event) {
        ws.ChangeDelta change = event.changes.single;
        expect(change.resource.name, fileEntry.name);
        expect(change.type, ws.EventType.ADD);
      });

      workspace.link(fileEntry).then((resource) {
        expect(resource, isNotNull);
        expect(workspace.getChildren().contains(resource), isTrue);
        expect(workspace.getFiles().contains(resource), isTrue);
      });

      return future;
    });

    test('delete file, check for resource delete event', () {
      var workspace = new ws.Workspace();
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

      return workspace.onResourceChange.first.then((ws.ResourceChangeEvent event) {
        ws.ChangeDelta change = event.changes.single;
        expect(change.resource.name, fileEntry.name);
        expect(change.type, ws.EventType.DELETE);
      });

    });

    test('add directory, check for resource add event', () {
      var workspace = new ws.Workspace();
      MockFileSystem fs = new MockFileSystem();
      fs.createFile('/myProject/test.txt');
      fs.createFile('/myProject/test.html');
      fs.createFile('/myProject/test.dart');
      var dirEntry = fs.getEntry('myProject');

      Future future = workspace.onResourceChange.first.then((ws.ResourceChangeEvent event) {
        ws.ChangeDelta change = event.changes.single;
        expect(change.resource.name, dirEntry.name);
        expect(change.type, ws.EventType.ADD);
      });

      workspace.link(dirEntry).then((project) {
        expect(project, isNotNull);
        expect(workspace.getChildren().contains(project), isTrue);
        expect(workspace.getProjects().contains(project), isTrue);
        var children = (project as ws.Container).getChildren();
        expect(children.length, 3);
      });

      return future;
    });

    test('add directory with folders, check for resource add event', () {
      var workspace = new ws.Workspace();
      MockFileSystem fs = new MockFileSystem();
      var projectDir = fs.createDirectory('myProject');
      fs.createFile('/myProject/index.html');
      fs.createFile('/myProject/myApp.dart');
      fs.createFile('/myProject/myApp.css');
      var dirEntry = fs.createDirectory('/myProject/myDir');
      fs.createFile('/myProject/myDir/test.txt');
      fs.createFile('/myProject/myDir/test.html');
      fs.createFile('/myProject/myDir/test.dart');

      Future future = workspace.onResourceChange.first.then((ws.ResourceChangeEvent event) {
        ws.ChangeDelta change = event.changes.single;
        expect(change.resource.name, projectDir.name);
        expect(change.type, ws.EventType.ADD);
      });

      workspace.link(projectDir).then((project) {
        expect(project, isNotNull);
        expect(workspace.getChildren().contains(project), isTrue);
        expect(workspace.getProjects().contains(project), isTrue);
        var children = (project as ws.Container).getChildren();
        expect(children.length, 4);
        for (var child in children){
          if (child is ws.Folder) {
            expect((child as ws.Folder).getChildren().length, 3);
          }
        }
      });
      return future;
    });

    test('refresh from filesystem', () {
      var workspace = new ws.Workspace();
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
        ws.Folder dir = project.getChild('myDir');
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
      ws.Workspace workspace = new ws.Workspace();
      var rootDir = fs.createDirectory('/root');
      fs.createDirectory('/root/folder1');
      fs.createDirectory('/root/folder2');
      fs.createDirectory('/root/folder1/folder3');
      fs.createFile('/root/folder1/file1');
      fs.createFile('/root/folder1/folder3/file2');
      fs.createFile('/root/folder2/file3');
      return workspace.link(rootDir).then((_) {
        ws.Folder rootFolder = workspace.getChild('root');
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

    test("create marker on resource, check for marker add event", () {
      var workspace = new ws.Workspace();
      MockFileSystem fs = new MockFileSystem();
      var projectDir = fs.createDirectory('myProject');
      fs.createFile('/myProject/index.html');
      fs.createFile('/myProject/myApp.dart');
      Future future = workspace.onMarkerChange.first.then((ws.MarkerChangeEvent event) {
        expect(event.changes.first.resource.name, 'myApp.dart');
        expect(event.changes.first.type, ws.EventType.ADD);
      });

      return workspace.link(projectDir).then((project) {
        ws.File file = project.getChild('myApp.dart');
        file.createMarker('dart', ws.Marker.SEVERITY_ERROR, 'error marker', 2);
        var markers = file.getMarkers();
        expect(markers.length, 1);
        expect(markers.first.file, file);
        expect(markers.first.type, 'dart');
        expect(markers.first.severity, ws.Marker.SEVERITY_ERROR);
        return future;
      });
    });

    test("create different types of markers and clear markers", () {
      var workspace = new ws.Workspace();
      MockFileSystem fs = new MockFileSystem();
      var projectDir = fs.createDirectory('myProject');
      fs.createFile('/myProject/index.html');
      fs.createFile('/myProject/myApp.dart');

      return workspace.link(projectDir).then((project) {
        ws.File file = project.getChild('myApp.dart');
        file.createMarker('dart', ws.Marker.SEVERITY_ERROR, 'error marker', 2);
        file.createMarker('dart', ws.Marker.SEVERITY_WARNING, 'dart warning marker', 6);
        var markers = file.getMarkers();
        expect(markers.length, 2);
        expect(markers.first.file, file);
        expect(markers.first.type, 'dart');
        expect(markers.first.severity, ws.Marker.SEVERITY_ERROR);
        ws.File htmlFile = project.getChild('index.html');
        htmlFile.createMarker('html', ws.Marker.SEVERITY_WARNING, 'warning marker', 5);
        htmlFile.createMarker('html', ws.Marker.SEVERITY_INFO, 'info', 3);
        markers = htmlFile.getMarkers();
        expect(markers.length, 2);
        expect(markers.first.file, htmlFile);
        expect(markers.first.type, 'html');
        expect(markers.first.severity, ws.Marker.SEVERITY_WARNING);
        markers = project.getMarkers();
        expect(markers.length, 4);
        project.clearMarkers();
        markers = project.getMarkers();
        expect(markers.length, 0);
      });

    });

    test("create and clear marker, check for delete event", () {
      var workspace = new ws.Workspace();
      MockFileSystem fs = new MockFileSystem();
      var projectDir = fs.createDirectory('myProject');
      fs.createFile('/myProject/index.html');
      fs.createFile('/myProject/myApp.dart');

      Future future = workspace.onMarkerChange.skip(1).first.then((ws.MarkerChangeEvent event) {
        expect(event.changes.first.resource.name, 'myApp.dart');
        expect(event.changes.first.type, ws.EventType.DELETE);
      });

      return workspace.link(projectDir).then((project) {
        ws.File file = project.getChild('myApp.dart');
        file.createMarker('dart', ws.Marker.SEVERITY_ERROR, 'error marker', 2);
        var markers = file.getMarkers();
        expect(markers.length, 1);
        file.clearMarkers();
        markers = file.getMarkers();
        expect(markers.length, 0);
        return future;
      });
    });

    test("get max severity marker", () {
      var workspace = new ws.Workspace();
      MockFileSystem fs = new MockFileSystem();
      var projectDir = fs.createDirectory('myProject');
      fs.createFile('/myProject/index.html');
      fs.createFile('/myProject/myApp.dart');
      fs.createFile('myProject/myLib.dart');

      return workspace.link(projectDir).then((project) {
        ws.File file = project.getChild('myApp.dart');
        file.createMarker('dart', ws.Marker.SEVERITY_ERROR, 'error marker', 2);
        file.createMarker('dart', ws.Marker.SEVERITY_WARNING, 'dart warning marker', 6);
        ws.File htmlFile = project.getChild('index.html');
        htmlFile.createMarker('html', ws.Marker.SEVERITY_WARNING, 'warning marker', 5);
        htmlFile.createMarker('html', ws.Marker.SEVERITY_INFO, 'info', 3);
        file = project.getChild('myLib.dart');
        file.createMarker('dart', ws.Marker.SEVERITY_WARNING, 'dart warning', 3);
        file.createMarker('dart', ws.Marker.SEVERITY_INFO, 'dart info marker', 4);

        int severity = project.findMaxProblemSeverity();
        expect(severity, ws.Marker.SEVERITY_ERROR);
        severity = htmlFile.findMaxProblemSeverity();
        expect(severity, ws.Marker.SEVERITY_WARNING);
      });
    });

    test("pause and resume posting marker events", () {
      var workspace = new ws.Workspace();
      MockFileSystem fs = new MockFileSystem();
      var projectDir = fs.createDirectory('myProject');
      fs.createFile('/myProject/myApp.dart');
      Future future2 = workspace.onMarkerChange.skip(1).first.then((ws.MarkerChangeEvent event) {
        expect(event.changes.length, 2);
      });
      Future future =  workspace.onMarkerChange.first.then((ws.MarkerChangeEvent event){
        expect(event.changes.length, 1);
      });
      return workspace.link(projectDir).then((project) {
        ws.File file = project.getChild('myApp.dart');
        file.createMarker('dart', ws.Marker.SEVERITY_WARNING, 'warning marker', 2);
        return future.then((_) {
          workspace.pauseMarkerStream();
          file.createMarker('dart', ws.Marker.SEVERITY_ERROR, 'error marker', 2);
          file.createMarker('dart', ws.Marker.SEVERITY_INFO, 'dart info marker', 4);
          workspace.resumeMarkerStream();
          return future2;
        });
      });
    });
  });
}
