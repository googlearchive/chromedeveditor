// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.pull;

import 'dart:async';

import 'package:chrome/chrome_app.dart' as chrome;

import '../exception.dart';
import '../file_operations.dart';
import '../objectstore.dart';
import '../options.dart';
import '../utils.dart';
import 'checkout.dart';
import 'commit.dart';
import 'constants.dart';
import 'fetch.dart';
import 'merge.dart';

/**
 * A git pull command implmentation.
 *
 * TODO(grv): Add unittests.
 */
class Pull {
  final GitOptions options;
  chrome.DirectoryEntry root;
  ObjectStore store;
  Function progress;

  Pull(this.options) {
    root = options.root;
    store = options.store;
    progress = options.progressCallback;

    if (progress == null) progress = nopFunction;
  }

  Future pull() {
    String username = options.username;
    String password = options.password;

    Function fetchProgress;
    // TODO(grv): Add fetchProgress chunker.

    Fetch fetch = new Fetch(options);

    Future merge() {
      return store.getHeadRef().then((String headRefName) {
        return store.getHeadForRef(headRefName).then((String localSha) {
          return store.getRemoteHeadForRef(headRefName).then(
              (String remoteSha) {
            if (remoteSha == localSha) {
              throw new GitException(GitErrorConstants.GIT_BRANCH_UP_TO_DATE);
            }
            return store.getCommonAncestor([remoteSha, localSha]).then(
                (commonSha) {
              if (commonSha == remoteSha) {
                throw new GitException(GitErrorConstants.GIT_BRANCH_UP_TO_DATE);
              } else if (commonSha == localSha) {
                // Move the localHead to remoteHead, and checkout.
                return FileOps.createFileWithContent(root,
                    '.git/${headRefName}', remoteSha, 'Text').then((_) {
                  return store.getCurrentBranch().then((branch) {
                    options.branchName = branch;
                    return Checkout.checkout(options, true);
                  });
                });
              } else {
                var shas = [localSha, commonSha, remoteSha];
                return store.getTreesFromCommits(shas).then((trees) {
                  return Merge.mergeTrees(store, trees[0], trees[1], trees[2])
                      .then((String finalTreeSha) {
                    return store.getCurrentBranch().then((branch) {
                      options.branchName = branch;
                      options.commitMessage = MERGE_BRANCH_COMMIT_MSG
                        + options.branchName;
                      // Create a merge commit by default.
                      return Commit.createCommit(options, localSha, finalTreeSha,
                           headRefName).then((_) {
                        return Checkout.checkout(options, true);
                      });
                    });
                  }).catchError((e) {
                    return throw new GitException(GitErrorConstants.GIT_MERGE_ERROR);
                  });
                });
              }
            });
          });
        });
      });
    }
    return fetch.fetch().then((_) {
      return merge();
    }).catchError((e) {
      return merge();
    });
  }
}
