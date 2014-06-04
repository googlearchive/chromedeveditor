// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.checkout;

import 'dart:async';

import 'package:chrome/chrome_app.dart' as chrome;

import 'merge.dart';
import '../constants.dart';
import '../exception.dart';
import '../file_operations.dart';
import '../object.dart';
import '../object_utils.dart';
import '../objectstore.dart';
import '../options.dart';
import 'status.dart';

/**
 * This class implments the git checkout command.
 */
class Checkout {

  static Future _removeEntryRecursively(ObjectStore store,
    chrome.DirectoryEntry dir, TreeEntry treeEntry) {

    if (treeEntry.isBlob) {
      return dir.getFile(treeEntry.name).then((fileEntry) {
        store.index.deleteIndexForEntry(fileEntry.fullPath);
        return fileEntry.remove();
      });
    }

    return dir.getDirectory(treeEntry.name).then((newDir) {
      store.index.deleteIndexForEntry(newDir.fullPath);
      return store.retrieveObject(treeEntry.sha, "Tree").then((GitObject tree) {
        return Future.forEach((tree as TreeObject).entries, (TreeEntry entry) {
          return _removeEntryRecursively(store, newDir, entry);
        }).then((_) {
          // There might be untracked files in the project. Only delete the
          // directory if it is empty.
          return FileOps.listFiles(newDir).then((entries) {
            if (entries.isEmpty) {
              return newDir.remove();
            }
          });
        });
      });
    });
  }

  static Future smartCheckout(chrome.DirectoryEntry dir, ObjectStore store,
      TreeObject oldTree, TreeObject newTree) {
    TreeDiffResult diff = Merge.diffTree(oldTree, newTree);
    return Future.forEach(diff.adds, (TreeEntry entry) {
      if (entry.isBlob) {
        return ObjectUtils.expandBlob(dir, store, entry.name, entry.sha);
      } else {
        return dir.createDirectory(entry.name).then((newDir) {
          return ObjectUtils.expandTree(newDir, store, entry.sha);
        });
      }
    }).then((_) {
      return Future.forEach(diff.removes, (TreeEntry entry) {
        return _removeEntryRecursively(store, dir, entry);
      }).then((_) {
        return Future.forEach(diff.merges, (mergeEntry) {
          TreeEntry oldEntry = mergeEntry['old'];
          TreeEntry newEntry = mergeEntry['new'];
          if (newEntry.isBlob) {
            return ObjectUtils.expandBlob(dir, store, newEntry.name,
                newEntry.sha);
          } else {
            return store.retrieveObjectList([oldEntry.sha, newEntry.sha],
                "Tree").then((trees) {
              return dir.createDirectory(newEntry.name).then((newDir) {
                return smartCheckout(newDir, store, trees[0], trees[1]);
              });
            });
          }
        });
      });
    });
  }

  /**
   * Switches the workspace to a given git branch.
   * Throws a BRANCH_NOT_FOUND exception if the branch does not exist.
   *
   * TODO(grv): Support checkout of single file, commit heads etc.
   */
  static Future checkout(GitOptions options, [bool force=false]) {
    chrome.DirectoryEntry root = options.root;
    ObjectStore store = options.store;
    String branch = options.branchName;

    return store.getHeadForRef(REFS_HEADS + branch).then(
        (String branchSha) {
      return store.getHeadSha().then((String currentSha) {
        if (currentSha != branchSha || force) {
          return Status.isWorkingTreeClean(store).then((_) {
            return store.getTreesFromCommits([currentSha, branchSha]).then(
                (List<TreeObject> trees) {
              return smartCheckout(root, store, trees[0], trees[1]).then((_) {
                return store.setHeadRef(REFS_HEADS + branch, '');
              });
            });
          });
        } else {
          return store.setHeadRef(REFS_HEADS + branch, '');
        }
      });
    }, onError: (e) {
      throw new GitException(GitErrorConstants.GIT_BRANCH_NOT_FOUND);
    });
  }
}
