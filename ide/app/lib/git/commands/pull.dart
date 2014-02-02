// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.pull;

import 'dart:async';

import 'package:chrome/chrome_app.dart' as chrome;

import '../file_operations.dart';
import '../objectstore.dart';
import '../options.dart';
import '../utils.dart';
import 'checkout.dart';
import 'fetch.dart';

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

    Future merge() {
      return store.getHeadRef().then((String headRefName) {
        return store.getHeadForRef(headRefName).then((String localSha) {
          return store.getRemoteHeadForRef(headRefName).then(
              (String remoteSha) {
            if (remoteSha == localSha) {
              throw "branch is up-to-date.";
            }
            return _checkFastForward(remoteSha, localSha).then((isFastForward) {
              if (isFastForward) {
                // Move the localHead to remoteHead, and checkout.
                return FileOps.createFileWithContent(root,
                    '.git/${headRefName}', remoteSha, 'Text').then((_) {
                  return store.getCurrentBranch().then((branch) {
                    options.branchName = branch;
                    return Checkout.checkout(options, true);
                  });
                });
              } else {
                return store.getCommonAncestor([remoteSha, localSha]).then((sha) {
                  throw "non-fast-forward merge is not yet supported.";
                });
              }
            });
          });
        });
      });
    }

    return fetch.fetch().then((_) {
      return merge();
    });
  }

  Future<bool> _checkFastForward(String remoteSha, String localSha) {
    return store.getCommitGraph([remoteSha], 10000).then(
        (CommitGraph graph) {
      return graph.commits.any((commit) => commit.sha == localSha);
    });
  }
}
