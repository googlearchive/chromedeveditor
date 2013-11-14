// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.objects.utils;

import 'dart:async';
import 'dart:core';

import 'package:chrome_gen/chrome_app.dart' as chrome;

import 'file_operations.dart';
import 'git_object.dart';
import 'git_objectstore.dart';
import 'git_utils.dart';

/**
 * Utilities function for git objects.
 * TODO(grv) : Add unittests.
 */
abstract class ObjectUtils {
  /**
   * Expands a git blob object into a file and writes ond disc.
   */
  static Future<chrome.Entry> expandBlob(chrome.DirectoryEntry dir, ObjectStore store,
      String fileName, String blobSha) {
    return store.retrieveObject(blobSha, "Blob").then((BlobObject blob) {
      return FileOps.createFileWithContent(dir, fileName, blob.data, "Blob");
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
            return expandTree(dir, store, sha);
          });
        }
      });
    });
  }
}
