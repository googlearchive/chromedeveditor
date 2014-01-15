// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.checkout;

import 'dart:async';
import 'dart:html';

import 'package:chrome/chrome_app.dart' as chrome;

import '../constants.dart';
import '../file_operations.dart';
import '../object.dart';
import '../object_utils.dart';
import '../objectstore.dart';
import '../options.dart';
import 'conditions.dart';

/**
 * This class implments the git checkout command.
 */
class Checkout {

  /**
   * Clears the git working directory.
   */
  static Future _cleanWorkingDir(chrome.DirectoryEntry root) {
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
   * Throws a BRANCH_NOT_FOUND error if the branch does not exist.
   */
  static Future checkout(GitOptions options) {
    chrome.DirectoryEntry root = options.root;
    ObjectStore store = options.store;
    String branch = options.branchName;

    return store.getHeadForRef(REFS_HEADS + branch).then(
        (String branchSha) {
      return store.getHeadSha().then((String currentSha) {
        if (currentSha != branchSha) {
          return Conditions.checkForUncommittedChanges(root, store).then(
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
          return store.setHeadRef(REFS_HEADS + branch, '');
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
