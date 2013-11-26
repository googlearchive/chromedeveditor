// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.checkout;

import 'dart:async';
import 'dart:html';

import 'package:chrome_gen/chrome_app.dart' as chrome;

import '../constants.dart';
import '../file_operations.dart';
import '../git.dart';
import '../object.dart';
import '../object_utils.dart';
import '../objectstore.dart';

class Checkout {

  Future<GitConfig> checkForUncommittedChanges(chrome.DirectoryEntry dir,
      ObjectStore store) {
    return null;
  }

  /**
   * Clears the git working directory.
   */
  Future _cleanWorkingDir(chrome.DirectoryEntry root) {
    return FileOps.listFiles(root).then((List<chrome.DirectoryEntry> entries) {
      return Future.forEach(entries, (chrome.DirectoryEntry entry) {
        if (entry.isDirectory) {
           // Do not remove the .git directory.
           if (entry.name == '.git') {
            return null;
          }
          return entry.removeRecursively();
        } else {
          return entry.remove();
        }
      });
    });
  }

  /**
   * Switches the workspace to a given git branch.
   */
  Future checkout(GitOptions options) {
    chrome.DirectoryEntry root = options.root;
    ObjectStore store = options.store;
    String branch = options.branchName;

    return store.getHeadForRef(REFS_HEADS + 'branch').then(
        (String branchSha) {
      return store.getHeadSha().then((String currentSha) {
        if (currentSha != branchSha) {
          return checkForUncommittedChanges(root, store).then(
              (GitConfig config) {
            return _cleanWorkingDir(root).then((_) {
              return store.retrieveObject(branchSha, ObjectTypes.COMMIT).then(
                  (CommitObject commit) {
                return ObjectUtils.expandTree(root, store, commit.treeSha)
                    .then((_) {
                  return store.setHeadRef(REFS_HEADS + branch, '').then((_) {
                    return store.updateLastChange(config);
                  });
                });
              });
            });
          });
        } else {
          return store.setHeadRef(REFS_HEADS + 'branch', '');
        }
      });
    }, onError: (e) {
      if (e.code == FileError.NOT_FOUND_ERR) {
        // TODO(grv) throw checkout branch does not exist.
      } else {
        throw e;
      }
    });
  }
}