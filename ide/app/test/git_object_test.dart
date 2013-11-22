// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git_object_test;

import 'package:unittest/unittest.dart';

import '../lib/git/git_object.dart';

defineTests() {
  group('git.objects', () {
    test('createObject', () {
      String sha = "shastring";
      String content ="contentstring";
      GitObject gitobject = GitObject.make(sha, "blob", content);
      expect(gitobject is BlobObject, true);
    });
  });
}
