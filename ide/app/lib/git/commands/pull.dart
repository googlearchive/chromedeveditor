// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.pull;

import 'dart:async';

import 'package:chrome/chrome_app.dart' as chrome;

import '../file_operations.dart';
import '../object.dart';
import '../object_utils.dart';
import '../objectstore.dart';
import '../options.dart';
import '../utils.dart';
import 'fetch.dart';
import 'merge.dart';

/**
 * A git pull command implmentation.
 *
 * TODO add unittests.
 */
class Pull {

  GitOptions options;
  chrome.DirectoryEntry root;
  ObjectStore store;
  Function progress;


  Pull(this.options){
    root = options.root;
    store = options.store;
    progress = options.progressCallback;

    if (progress == null) progress = nopFunction;
  }

  Future pull() {
    String username = options.username;
    String password = options.password;

    Function fetchProgress;
    // TODO add fetchProgress chunker.

    Fetch fetch = new Fetch(options);
    return fetch.fetch().then((_) {
      return store.getHeadRef().then((String headRefName) {
        return store.getHeadForRef(headRefName).then((String localSha) {
          return store.getRemoteHeadForRef(headRefName).then((String remoteSha) {
          });
        });
      });
    });
  }

  Future _createAndUpdateRef(String refName, String localSha,
      String remoteSha) {
    return FileOps.createFileWithContent(root, '.git/${refName}', remoteSha,
        'Text').then((_) {
      store.getTreesFromCommits([localSha, remoteSha]).then(
          (List<TreeObject> trees) {
        return _applyDiffTree(root, Merge.diffTree(trees[0], trees[1]),
            store).then((_) {
          store.config.remoteHeads[refName] = remoteSha;
          return store.writeConfig();
        });
      });
    });
  }

  static Future _applyDiffTree(chrome.DirectoryEntry dir,
      TreeDiffResult  treeDiff, ObjectStore store) {
    return Future.forEach(treeDiff.removes, (TreeEntry treeEntry) {
      if (treeEntry.isBlob) {
        return dir.getFile(treeEntry.name).then((chrome.FileEntry entry) {
          return entry.remove();
        });
      } else {
        return dir.getDirectory(treeEntry.name).then(
            (chrome.DirectoryEntry entry) {
          return entry.removeRecursively();
        });
      }
    }).then((_) {
      return Future.forEach(treeDiff.adds, (TreeEntry treeEntry) {
        if (treeEntry.isBlob) {
          return ObjectUtils.expandBlob(dir, store, treeEntry.name,
              shaBytesToString(treeEntry.sha));
        } else {
          return dir.createDirectory(treeEntry.name).then(
              (chrome.DirectoryEntry dirEntry) {
            return ObjectUtils.expandTree(dirEntry, store,
                shaBytesToString(treeEntry.sha));
          });
        }
      }).then((_) {
        return Future.forEach(treeDiff.merges, (mergeEntry) {
          if (mergeEntry['new'].isBlob) {
            return ObjectUtils.expandBlob(dir, store, mergeEntry['new'].name,
                shaBytesToString(mergeEntry['new'].sha));
          } else {
            return store.retrieveObjectList([mergeEntry['old'].sha,
                mergeEntry['new'].sha], ObjectTypes.TREE_STR).then(
                (List<TreeObject> trees) {
              TreeDiffResult treeDiff2 = Merge.diffTree(trees[0], trees[1]);
              return dir.createDirectory(mergeEntry['new'].name).then(
                  (chrome.DirectoryEntry dirEntry) {
                return _applyDiffTree(dirEntry, treeDiff2, store);
              });
            });
          }
        });
      });
    });
  }
}
