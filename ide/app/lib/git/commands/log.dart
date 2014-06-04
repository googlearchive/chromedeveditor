// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.log;

import 'dart:async';

import '../constants.dart';
import '../exception.dart';
import '../object.dart';
import '../objectstore.dart';

/**
 * State based implementation of Log. Repeated calls to log will get parent
 * commit objects in order to avoid retrieving the entire log in a single call.
 */
class Log {
  String _branch;
  CommitGraph _graph;

  // Integer specifying the number of commits to return with each successive
  // call to getNextCommits.
  int _increment;

  List<String> _nextHeadShas;
  ObjectStore _store;

  /**
   * Sets up the Log object. Optional [branch] specifies a branch
   * other than the current head. Optional [increment] specifies a number of
   * commits to return with each successive call (defaults to 1).
   */
  Log(this._store, {String branch, int increment: 1}) {
    _branch = branch;
    _increment = increment;
  }

  /**
   * Internal function for discovering the first sha to examine for commits.
   */
  static Future<String> _getBaseSha(ObjectStore store, String branch) {
    if (branch == null || branch.isEmpty)
      return store.getHeadSha();
    return store.getLocalHeads().then((List<String> branches) {
      if (!branches.contains(branch))
        throw new GitException(GitErrorConstants.GIT_BRANCH_NOT_FOUND);
      return store.getHeadForRef('${REFS_HEADS}${branch}');
    });
  }

  /**
   * Internal function for listing commits and storing the next sha to be
   * examined.
   */
  Future<List<CommitObject>> _listCommits() {
    return _store.getCommitGraph(_nextHeadShas, _increment).then(
        (CommitGraph graph) {
      if (graph.commits.length > 0)
        _nextHeadShas = graph.commits.last.parents;
      return graph.commits;
    });
  }

  /**
   * A state based function for successively retrieving a list of commit
   * objects in small chunks.
   */
  Future<List<CommitObject>> getNextCommits() {
    if (_nextHeadShas != null)
      return _listCommits();
    return _getBaseSha(_store, _branch).then((String baseSha) {
      _nextHeadShas = [baseSha];
      return _listCommits();
    });
  }

  /**
   * A static function for retrieving a list of all commit objects above a
   * branch head. Passing in an optional limit variable will return at most
   * that many commit objects.
   */
  static Future<List<CommitObject>> getAllCommits(
      ObjectStore store, String branch, {int limit}) {
    return _getBaseSha(store, branch).then((String baseSha) {
      return store.getCommitGraph([baseSha], limit).then((CommitGraph graph) {
        return graph.commits;
      });
    });
  }
}
