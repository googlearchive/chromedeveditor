// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.builder_test;

import 'dart:async';

import 'package:unittest/unittest.dart';

import '../lib/builder.dart';
import '../lib/files_mock.dart';
import '../lib/jobs.dart';
import '../lib/preferences.dart';
import '../lib/workspace.dart';

defineTests() {
  group('builder', () {
    test('change event triggers builder', () {
      Workspace workspace = new Workspace(new MapPreferencesStore());
      var jobManager = new JobManager();
      var buildManager = new BuilderManager(workspace, jobManager);

      Completer completer = new Completer();
      buildManager.builders.add(new MockBuilder(completer, changeCount: 2));

      MockFileSystem fs = new MockFileSystem();
      FileEntry fileEntry = fs.createFile('foo/test.txt');
      fileEntry.getParent().then((parent) {
        workspace.link(createWsRoot(parent));
      });

      return completer.future;
    });

    test('events coalesced', () {
      Workspace workspace = new Workspace(new MapPreferencesStore());
      var jobManager = new JobManager();
      var buildManager = new BuilderManager(workspace, jobManager);

      Completer completer = new Completer();
      buildManager.builders.add(new MockBuilder(completer, changeCount: 3));

      MockFileSystem fs = new MockFileSystem();
      FileEntry fileEntry1 = fs.createFile('foo/test1.txt');
      FileEntry fileEntry2 = fs.createFile('foo/test2.txt');

      fileEntry1.getParent().then((parent) {
        workspace.link(createWsRoot(parent));
      });

      return completer.future;
    });

    test('multiple builders', () {
      Workspace workspace = new Workspace(new MapPreferencesStore());
      var jobManager = new JobManager();
      var buildManager = new BuilderManager(workspace, jobManager);

      Completer completer1 = new Completer();
      Completer completer2 = new Completer();
      buildManager.builders.add(new MockBuilder(completer1, changeCount: 2));
      buildManager.builders.add(new MockBuilder(completer2, changeCount: 2));

      MockFileSystem fs = new MockFileSystem();
      FileEntry fileEntry = fs.createFile('foo/test.txt');
      fileEntry.getParent().then((parent) {
        workspace.link(createWsRoot(parent));
      });

      return Future.wait([completer1.future, completer2.future]);
    });
  });
}

class MockBuilder extends Builder {
  final Completer completer;
  final int changeCount;

  MockBuilder(this.completer, {this.changeCount: 1});

  Future build(ResourceChangeEvent changes, ProgressMonitor monitor) {
    expect(changes.changes.length, changeCount);
    completer.complete();
    return new Future.value();
  }
}
