// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.builder_test;

import 'dart:async';

import 'package:unittest/unittest.dart';

import 'files_mock.dart';
import '../lib/builder.dart';
import '../lib/jobs.dart';
import '../lib/workspace.dart';

defineTests() {
  group('builder', () {
    test('change event triggers builder', () {
      Workspace workspace = new Workspace();
      var jobManager = new JobManager();
      var buildManager = new BuilderManager(workspace, jobManager);

      Completer completer = new Completer();
      buildManager.builders.add(new MockBuilder(completer));

      MockFileSystem fs = new MockFileSystem();
      FileEntry fileEntry = fs.createFile('test.txt');
      workspace.link(createWsRoot(fileEntry));

      return completer.future;
    });

    test('events coalesced', () {
      Workspace workspace = new Workspace();
      var jobManager = new JobManager();
      var buildManager = new BuilderManager(workspace, jobManager);

      Completer completer = new Completer();
      buildManager.builders.add(new MockBuilder(completer, 2));

      MockFileSystem fs = new MockFileSystem();
      FileEntry fileEntry1 = fs.createFile('test1.txt');
      FileEntry fileEntry2 = fs.createFile('test2.txt');

      workspace.link(createWsRoot(fileEntry1));
      workspace.link(createWsRoot(fileEntry2));

      return completer.future;
    });

    test('multiple builders', () {
      Workspace workspace = new Workspace();
      var jobManager = new JobManager();
      var buildManager = new BuilderManager(workspace, jobManager);

      Completer completer1 = new Completer();
      Completer completer2 = new Completer();
      buildManager.builders.add(new MockBuilder(completer1));
      buildManager.builders.add(new MockBuilder(completer2));

      MockFileSystem fs = new MockFileSystem();
      FileEntry fileEntry = fs.createFile('test.txt');
      workspace.link(createWsRoot(fileEntry));

      return Future.wait([completer1.future, completer2.future]);
    });
  });
}

class MockBuilder extends Builder {
  final Completer completer;
  final int changeCount;

  MockBuilder(this.completer, [this.changeCount = 1]);

  Future build(ResourceChangeEvent changes, ProgressMonitor monitor) {
    expect(changes.changes.length, changeCount);
    completer.complete();
    return new Future.value();
  }
}
