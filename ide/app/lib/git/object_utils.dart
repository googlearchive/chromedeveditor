// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.objects.utils;

import 'dart:async';
import 'dart:core';

import 'package:chrome/chrome_app.dart' as chrome;

import 'file_operations.dart';
import 'object.dart';
import 'objectstore.dart';
import 'utils.dart';

/**
 *
 */
abstract class ObjectTypes {
  static const String BLOB = "blob";
  static const String TREE = "tree";
  static const String COMMIT = "commit";
  static const String TAG = "tag";
}

/**
 * Utilities function for git objects.
 * TODO(grv) : Add unittests.
 */
abstract class ObjectUtils {
  /**
   * Expands a git blob object into a file and writes on disc.
   */
  static Future<chrome.Entry> expandBlob(chrome.DirectoryEntry dir, ObjectStore store,
      String fileName, String blobSha) {
    return store.retrieveObject(blobSha, ObjectTypes.BLOB).then((BlobObject blob) {
      return FileOps.createFileWithContent(dir, fileName, blob.data, ObjectTypes.BLOB);
    });
  }

  /**
   * Expand a git tree object into files and writes on disk.
   */
  static Future expandTree(chrome.DirectoryEntry dir, ObjectStore store,
      String treeSha) {
    return store.retrieveObject(treeSha, "Tree").then((GitObject tree) {
      return Future.forEach((tree as TreeObject).entries, (TreeEntry entry) {
        String sha = shaBytesToString(entry.sha);
        if (entry.isBlob) {
          return expandBlob(dir, store, entry.name, sha);
        } else {
          return dir.createDirectory(entry.name).then(
              (chrome.DirectoryEntry newDir) {
            return expandTree(newDir, store, sha);
          });
        }
      });
    });
  }
}
