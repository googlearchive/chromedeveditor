// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.log;

import 'dart:async';

import '../object.dart';
import '../objectstore.dart';

/**
 * State based implementation of Log. Repeated calls to log will get parent
 * commit objects in order to avoid retrieving the entire log in a single call.
 */
class Log {
  List<String> _nextHeadSha;

  /**
   * Returns a list of CommitObjects.
   * store: ObjectStore from which to get commits.
   * branch: Branch from which to get commits. If null or empty the current
   * HEAD will be used.
   * length: Maximum number of commits to list. If null all commits will be
   * listed.
   */
  Future<List<CommitObject>> log(ObjectStore store, int length, [String branch]) {
    Future<List<CommitObject>> listCommits(List<String> headSha) {
      return store.getCommitGraph(headSha, length).then(
          (CommitGraph graph) {
        List<CommitObject> commits = graph.commits;
        if (commits.length > 0) {
          CommitObject next = commits[commits.length - 1];
          _nextHeadSha = next.parents;
        }
        return commits;
      });
    }

    if (_nextHeadSha != null && length != null)
      return listCommits(_nextHeadSha);

    if (branch == null || branch.isEmpty) {
      return store.getHeadSha().then(
          (String headSha) => listCommits([headSha]));
    }
    return store.getAllHeads().then((List<String> branches) {
      if (!branches.contains(branch)) {
        // TODO: Improve error handling.
        throw "No such branch exists.";
      }
      return store.getHeadForRef('refs/heads/$branch').then(
          (String headSha) => listCommits([headSha]));
    });
  }
}