// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.log;

import 'dart:async';

import '../objectstore.dart';

class Log {
  /**
   * Returns a list of CommitObjects.
   * store: ObjectStore from which to get commits.
   * branch: Branch from which to get commits. If empty
   * length: Maximum number of commits to list.
   *
   * TODO (camfitz): Add offset to skip the first 'n' commits.
   */
  static Future log(ObjectStore store, int length, [String branch]) {
    Future listCommits(String headSha) {
      return store.getCommitGraph([headSha], length).then(
          (CommitGraph graph) => graph.commits);
    }

    if (branch == null || branch.isEmpty) {
      return store.getHeadSha().then(listCommits);
    }
    return store.getAllHeads().then((List<String> branches) {
      if (!branches.contains(branch)) {
        // TODO: Improve error handling.
        throw "No such branch exists.";
      }
      return store.getHeadForRef('refs/heads/$branch').then(listCommits);
    });
  }
}