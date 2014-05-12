// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.checkout;

import 'dart:async';
import 'dart:html';

import 'package:chrome/chrome_app.dart' as chrome;

import '../constants.dart';
import '../exception.dart';
import '../object.dart';
import '../object_utils.dart';
import '../objectstore.dart';
import '../options.dart';
import '../utils.dart';
import 'status.dart';

/**
 * This class implments the git checkout command.
 */
class Checkout {

  /**
   * Switches the workspace to a given git branch.
   * Throws a BRANCH_NOT_FOUND error if the branch does not exist.
   *
   * TODO(grv) : Support checkout of single file, commit heads etc.
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
            return cleanWorkingDir(root).then((_) {
              return store.retrieveObject(branchSha, ObjectTypes.COMMIT_STR).then(
                  (CommitObject commit) {
                return ObjectUtils.expandTree(root, store, commit.treeSha)
                    .then((_) {
                  store.index.reset(false);
                  return store.setHeadRef(REFS_HEADS + branch, '');
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
        throw new GitException(GitErrorConstants.GIT_BRANCH_NOT_FOUND);
      } else {
        throw e;
      }
    });
  }
}
