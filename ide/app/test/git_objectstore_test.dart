// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.git_objectstore_test;

import 'dart:async';

import 'dart:html';

import 'package:chrome_gen/chrome_app.dart' as chrome;
import 'package:unittest/unittest.dart';

import '../lib/git/file_operations.dart';
import '../lib/git/git_objectstore.dart';
import 'files_mock.dart';

final String GIT_ROOT_DIRECTORY_PATH = 'test/data/git';

Future getGitDirectory() {
  return chrome.runtime.getPackageDirectoryEntry().then(
      (chrome.DirectoryEntry dir) {
    return dir.getDirectory(GIT_ROOT_DIRECTORY_PATH);
  });
}

Future copyTestGitDirectory(MockFileSystem fs) {
  return getGitDirectory().then((chrome.DirectoryEntry gitDir) {
    return fs.root.createDirectory('.git').then((dst) {
      return FileOps.copyDirectory(gitDir, dst);
    });
  });
}

Future<ObjectStore> initStore(fs) {
  return copyTestGitDirectory(fs).then((chrome.DirectoryEntry root) {
    ObjectStore store = new ObjectStore(fs.root);
    return store.load().then((_) => store);
  });
}

defineTests() {

  group('git.objectstore', () {
    MockFileSystem fs = new MockFileSystem();
    test('load', () {
      return initStore(fs).then((ObjectStore store) {
        return store.getHeadRef().then((ref) {
          expect(ref, 'refs/heads/master');
          return store.getHeadSha().then((sha) {
            expect(sha, 'dc85576bd94bdcaff1bd60b0fb4cd032c8fa2c54');
            return store.getCommitGraph([sha], 32).then((commits) {
              window.console.log(commits);
            });
          });
        });
      });
    });
  });
}
