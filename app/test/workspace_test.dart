// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library workspace_test;

import 'dart:async';

import 'package:chrome_gen/chrome_app.dart' as chrome_gen;
import 'package:unittest/unittest.dart';

import '../lib/workspace.dart';

const _FILETEXT = 'This is sample text for mock file entry.';

class MockFileEntry implements chrome_gen.ChromeFileEntry {

  String _name;
  String _contents;

  MockFileEntry(String name) {
    _name = name;
  }

  String get name => _name;

  String get fullPath => _name;

  bool get isDirectory => false;

  bool get isFile => true;

  Future<String> readText() => new Future.value(_contents);

  noSuchMethod(Invocation msg) {
    super.noSuchMethod(msg);
  }
}

class MockDirectoryEntry implements chrome_gen.DirectoryEntry {

  String _name;
  List<chrome_gen.Entry> _entries = [];

  MockDirectoryEntry(String name) {
    _name = name;
  }

  String get name => _name;

  String get fullPath => _name;

  bool get isDirectory => true;

  bool get isFile => false;

 MockDirectoryReader createReader() => new MockDirectoryReader(_entries);

 noSuchMethod(Invocation msg) {
   super.noSuchMethod(msg);
 }
}

class MockDirectoryReader implements chrome_gen.DirectoryReader {

  List<chrome_gen.Entry> _entries = [];

  MockDirectoryReader(List<chrome_gen.Entry> entries) {
    _entries = entries;
  }

  Future<List<chrome_gen.Entry>> readEntries() => new Future.value(_entries);
}

main() {
  group('workspace', () {

    test('create file and check contents', () {
      var workspace = new Workspace(null);
      var fileEntry = new MockFileEntry('test.txt');
      fileEntry._contents = _FILETEXT;
      var fileResource = new File(workspace, fileEntry);
      expect(fileResource.name, fileEntry.name);
      fileResource.getContents().then((string) {
        expect(string, _FILETEXT);
      });
    });

    test('add file', () {
      var workspace = new Workspace(null);
      var fileEntry = new MockFileEntry('test.txt');
      workspace.link(fileEntry).then((resource) {
        expect(resource, isNotNull);
        expect(workspace.getChildren().contains(resource), isTrue);
        expect(workspace.getFiles().contains(resource), isTrue);
      });
    });

    test('add directory', () {
      var workspace = new Workspace(null);
      var dirEntry = new MockDirectoryEntry('myProject');
      dirEntry._entries = [new MockFileEntry('test.txt'),
                           new MockFileEntry('test.html'),
                           new MockFileEntry('test.dart')];
      workspace.link(dirEntry).then((project) {
        expect(project, isNotNull);
        expect(workspace.getChildren().contains(project), isTrue);
        expect(workspace.getProjects().contains(project), isTrue);
        var children = (project as Container).getChildren();
        expect(children.length, 3);
      });
    });

    test('add directory with folders', () {
      var workspace = new Workspace(null);
      var dirEntry = new MockDirectoryEntry('myDir');
      dirEntry._entries = [new MockFileEntry('test.txt'),
                           new MockFileEntry('test.html'),
                           new MockFileEntry('test.dart')];
      var projectDir = new MockDirectoryEntry('myProject');
      projectDir._entries = [new MockFileEntry('index.html'),
                             dirEntry,
                             new MockFileEntry('myApp.dart'),
                             new MockFileEntry('myApp.css')];

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
    });


  });
}


