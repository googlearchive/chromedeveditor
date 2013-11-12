// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.git_objectstore_test;

import 'dart:async';

import 'package:chrome_gen/chrome_app.dart' as chrome_gen;
import 'package:unittest/unittest.dart';

import '../lib/git/git_objectstore.dart';

final String GIT_ROOT_DIRECTORY_PATH = 'test';

Future getGitDirectory() {
  return chrome_gen.runtime.getPackageDirectoryEntry().then(
      (chrome_gen.DirectoryEntry dir) {
    return dir.createReader().readEntries().then((List entries) {
      chrome_gen.DirectoryEntry dir = entries.firstWhere(
          (e) => e.fullPath == '/crxfs/test');
      return dir.createReader().readEntries().then((List entries) {
        return entries.firstWhere((e) => e.fullPath == '/crxfs/test/data');
      });
    });
  });
}

main() {
  group('git.objectstore', () {
    test('load', () {
      return getGitDirectory().then((chrome_gen.DirectoryEntry root) {
        ObjectStore store = new ObjectStore(root);
        store.gitPath = 'git/';
        // TODO(grv): add asserts.
      });
    });
  });
}
