// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git_file_operations_test;

import 'dart:convert';
import 'dart:html';
import 'dart:typed_data';

import 'package:unittest/unittest.dart';

import '../files_mock.dart';
import '../../lib/git/file_operations.dart';

const String FILE_CONTENT = 'This is a test file content.';
const String BLOB_STRING_1 = 'First part of the blob.';
const String BLOB_STRING_2 = 'Second part of the blob';

defineTests() {
  group('git.file_operations', () {
    test('Create a folder whose parent does not exist.', () {
      MockFileSystem fs = new MockFileSystem();
      return FileOps.createDirectoryRecursive(fs.root, 'test/a/b').then((dir) {
        expect(fs.getEntry('test'), isNotNull);
        expect(fs.getEntry('test/a'), isNotNull);
        expect(dir.fullPath, '/root/test/a/b');
      });
    });

    test('Create a file whose parent does not exist.', () {
      MockFileSystem fs = new MockFileSystem();
      return FileOps.createFileWithContent(fs.root, 'test/a/b.txt',
          FILE_CONTENT, 'Text').then((ChromeFileEntry entry) {
        expect(fs.getEntry('test'), isNotNull);
        expect(fs.getEntry('test/a'), isNotNull);
        expect(entry.fullPath, '/root/test/a/b.txt');
        return entry.readText().then((String text) {
          expect(text, FILE_CONTENT);
        });
      });
    });

    test('Read a blob as string', () {
      List blobParts = [];
      blobParts.add(BLOB_STRING_1);
      blobParts.add(BLOB_STRING_2);
      Blob blob = new Blob(blobParts, 'Text');
      return FileOps.readBlob(blob, 'Text').then((String result) {
        expect(result, BLOB_STRING_1 + BLOB_STRING_2);
      });
    });

    test('Read a blob as ArrayBuffer', () {
      List blobParts = [];
      blobParts.add(BLOB_STRING_1);
      blobParts.add(BLOB_STRING_2);
      Blob blob = new Blob(blobParts, 'ArrayBuffer');
      return FileOps.readBlob(blob, 'ArrayBuffer').then((Uint8List result) {
        expect(UTF8.decode(result.toList()), BLOB_STRING_1 + BLOB_STRING_2);
      });
    });
  });
}
