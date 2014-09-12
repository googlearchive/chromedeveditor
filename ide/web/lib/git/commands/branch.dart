// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.branch;

import 'dart:async';

import 'package:chrome/chrome_app.dart' as chrome;

import 'fetch.dart';
import '../exception.dart';
import '../objectstore.dart';
import '../options.dart';

/**
 * This class implements the git branch command.
 */
class Branch {

  /* A valid branch name must :
   * 1) must not contain \ or ? or * or [] or ASCII control
   *    characters.
   * 2) no two consecutive '.'
   * 3) cannot begin or end with '/' or contain consecutive '/'.
   * 4) cannot end with a '.'
   * 5) Do not contain a sequence '@{'
   * 6) cannot end with '.lock'.
  */
  static const BRANCH_PATTERN
      = r"^(?!build-|/|.*([/.][.]|//|@\\{|\\\\))[^\040\177 ~^:?*\\[]+$";

  static final branchRegex = new RegExp(BRANCH_PATTERN);

  static bool _verifyBranchName(String name) {
    int length = name.length;
    return (name.isNotEmpty && branchRegex.matchAsPrefix(name) != null &&
        !name.endsWith('.') && !name.endsWith('.lock') && !name.endsWith('/'));
  }

  /**
   * Creates a new branch. Throws error if the branch already exist.
   */
  static Future<chrome.FileEntry> branch(
      GitOptions options, String sourceBranchName) {
    ObjectStore store = options.store;
    String branchName = options.branchName;

    if (!_verifyBranchName(branchName)) {
      return new Future.error(
          new GitException(GitErrorConstants.GIT_INVALID_BRANCH_NAME));
     }

    return store.getHeadForRef('refs/heads/' + branchName).then((_) {
      return new Future.error(
          new GitException(GitErrorConstants.GIT_BRANCH_EXISTS));
    }, onError: (e) {
      return _fetchAndCreateBranch(options, branchName, sourceBranchName);
    });
  }

  static Future<String> _fetchAndCreateBranch(
      GitOptions options, String branchName, String sourceBranchName) {
    ObjectStore store = options.store;
    // A remote branch is prefixed with 'origin/'.
    if (sourceBranchName.startsWith('origin/')) {
      sourceBranchName = sourceBranchName.split('/').last;
      return options.store.getRemoteHeadForRef(sourceBranchName).then((sha) {
        options.depth = 1;
        options.branchName = sourceBranchName;
        Fetch fetch = new Fetch(options);

        Function createBranch = () {
          options.branchName = branchName;
          return store.createLocalRef(branchName, sha);
        };

        return fetch.fetch().then((_) {
          return createBranch();
        }, onError: (GitException e) {
          if (e is! GitException ||
              e.errorCode != GitErrorConstants.GIT_FETCH_UP_TO_DATE) {
            return new Future.error(e);
          }
          return createBranch();
        });
      });
    } else {
      String refName = 'refs/heads/${sourceBranchName}';
      return store.getHeadForRef(refName).then((String sha) {
        return store.createLocalRef(branchName, sha);
      });
    }
  }
}
