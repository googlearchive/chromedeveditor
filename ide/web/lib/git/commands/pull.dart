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
  String username;
  String password;
  ObjectStore store;
  Function progress;

  Pull(this.options) {
    root = options.root;
    store = options.store;
    username = options.username;
    password = options.password;
    progress = options.progressCallback;

    if (progress == null) progress = nopFunction;
  }


  Future pull() {
    return new Fetch(options).fetch().then((_) => _merge())
        .catchError((GitException e) {
      // The branch head may be out of date. Update it.
      if (e.errorCode == GitErrorConstants.GIT_FETCH_UP_TO_DATE) {
        return _merge();
      }
      return new Future.error(e);
    });
  }

  Future _merge() {
    return store.getHeadRef().then((String headRefName) {
      return store.getHeadForRef(headRefName).then((String localSha) {
        return store.getRemoteHeadForRef(headRefName).then((String remoteSha) {
          if (remoteSha == localSha) {
            return new Future.error(
                new GitException(GitErrorConstants.GIT_BRANCH_UP_TO_DATE));
          }
          return store.getCommonAncestor([remoteSha, localSha]).then((commonSha) {
            if (commonSha == remoteSha) {
              return new Future.error(
                  new GitException(GitErrorConstants.GIT_BRANCH_UP_TO_DATE));
            } else if (commonSha == localSha) {
              return _fastForwardPull(headRefName, remoteSha);
            } else {
              return _nonFastForwardPull(localSha, commonSha, remoteSha);
            }
          });
        });
      });
    });
  }

  Future _fastForwardPull(String headRefName, String remoteSha) {
    return store.getCurrentBranch().then((branch) {
      options.branchName = branch;
      return Checkout.checkout(options, remoteSha).then((_) {
        // Move the localHead to remoteHead.
        return FileOps.createFileWithContent(
            root, '.git/${headRefName}', remoteSha, 'Text');
      });
    });
  }

  Future _nonFastForwardPull(String localSha, String commonSha, String remoteSha) {
    List shas = [localSha, commonSha, remoteSha];
    return store.getHeadRef().then((String headRefName) {
      return store.getTreesFromCommits(shas).then((trees) {
        return Merge.mergeTrees(store, trees[0], trees[1], trees[2])
            .then((String finalTreeSha) {
          return store.getCurrentBranch().then((branch) {
            options.branchName = branch;
            options.commitMessage = MERGE_BRANCH_COMMIT_MSG + options.branchName;
            // Create a merge commit by default.
            return Commit.createCommit(options, [remoteSha, localSha], finalTreeSha,
                headRefName).then((commitSha) {
              return Checkout.checkout(options, commitSha).then((_) {
                return FileOps.createFileWithContent(options.root, '.git/${headRefName}',
                    commitSha + '\n', 'Text').then((_) {
                  return store.writeConfig().then((_) => commitSha);
                });
              });
            });
          });
        }).catchError((e) {
          return new Future.error(
              new GitException(GitErrorConstants.GIT_MERGE_ERROR));
        });
      });
    });
  }
}
