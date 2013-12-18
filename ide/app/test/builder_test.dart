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
      var workspace = new Workspace();
      var jobManager = new JobManager();
      var buildManager = new BuilderManager(workspace, jobManager);

      Completer completer = new Completer();
      buildManager.builders.add(new MockBuilder(completer));

      MockFileSystem fs = new MockFileSystem();
      var fileEntry = fs.createFile('test.txt');
      workspace.link(fileEntry);

      return completer.future;
    });
  });
}

class MockBuilder extends Builder {
  final Completer completer;

  MockBuilder(this.completer);

  Future build(ResourceChangeEvent changes) {
    completer.complete();
  }
}
