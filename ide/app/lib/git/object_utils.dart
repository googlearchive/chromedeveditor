// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.objects.utils;

import 'dart:async';
import 'dart:core';

import 'package:chrome/chrome_app.dart' as chrome;

import 'file_operations.dart';
import 'commands/index.dart';
import 'object.dart';
import 'objectstore.dart';

/**
 *
 */
abstract class ObjectTypes {

  static const String BLOB_STR = "blob";
  static const String TREE_STR = "tree";
  static const String COMMIT_STR = "commit";
  static const String TAG_STR = "tag";
  static const String OFS_DELTA_STR = "ofs_delta";
  static const String REF_DELTA_STR = "ref_delta";

  static const int COMMIT = 1;
  static const int TREE = 2;
  static const int BLOB = 3;
  static const int TAG = 4;
  static const int OFS_DELTA = 6;
  static const int REF_DELTA = 7;

  static String getTypeString(int type) {
    switch(type) {
      case COMMIT:
        return COMMIT_STR;
      case TREE:
        return TREE_STR;
      case BLOB:
        return BLOB_STR;
      case TAG:
        return TAG_STR;
      case OFS_DELTA:
        return OFS_DELTA_STR;
      case REF_DELTA:
        return REF_DELTA_STR;
      default:
        throw "unsupported pack type ${type}.";
    }
  }

  static int getType(String type) {
    switch(type) {
      case COMMIT_STR:
        return COMMIT;
      case TREE_STR:
        return TREE;
      case BLOB_STR:
        return BLOB;
      case TAG_STR:
        return TAG;
      case OFS_DELTA_STR:
        return OFS_DELTA;
      case REF_DELTA_STR:
        return REF_DELTA;
      default:
        throw "unsupported pack type ${type}.";
    }
  }
}

/**
 * Utilities function for git objects.
 * TODO(grv) : Add unittests.
 */
abstract class ObjectUtils {
  /**
   * Expands a git blob object into a file and writes on disc.
   */
  static Future<chrome.Entry> expandBlob(chrome.DirectoryEntry dir,
      ObjectStore store, String fileName, String blobSha) {
    return store.retrieveObject(blobSha, ObjectTypes.BLOB_STR).then(
        (BlobObject blob) {
      return FileOps.createFileWithContent(dir, fileName, blob.data,
          ObjectTypes.BLOB_STR).then((chrome.Entry entry) {
        return entry.getMetadata().then((data) {
          FileStatus status = new FileStatus();
          status.path = entry.fullPath;
          status.sha = blobSha;
          status.headSha = blobSha;
          status.size = data.size;
          store.index.createIndexForEntry(status);
        });
      });
    });
  }

  /**
   * Expand a git tree object into files and writes on disk.
   */
  static Future expandTree(chrome.DirectoryEntry dir, ObjectStore store,
      String treeSha) {
    return store.retrieveObject(treeSha, "Tree").then((GitObject tree) {
      return Future.forEach((tree as TreeObject).entries, (TreeEntry entry) {
        if (entry.isBlob) {
          return expandBlob(dir, store, entry.name, entry.sha);
        } else {
          return dir.createDirectory(entry.name).then(
              (chrome.DirectoryEntry newDir) {
            return expandTree(newDir, store, entry.sha);
          });
        }
      });
    });
  }
}
