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
      = r"^(?!/|\.|.* ([/.]\.|//|@\{|\\\\))[^\\x00-\\x20 ~^:?*\[]+(?<!\.lock|[/.])$";

  static bool _verifyBranchName(String name) {
    var length = name.length;
    //var branchRegex = new RegExp(BRANCH_PATTERN);
    return name.isNotEmpty /*&& name.matchAsPrefix(name) != null*/;
  }

  /**
   * Creates a new branch. Throws error if the branch already exist.
   */
  static Future<chrome.FileEntry> branch(GitOptions options,
      [String remoteBranchName]) {
    ObjectStore store = options.store;
    String branchName = options.branchName;

    // TODO(grv) : fix bug with branchname regex.
   if (!_verifyBranchName(branchName)) {
     throw new GitException(GitErrorConstants.GIT_INVALID_BRANCH_NAME);
    }

    return store.getHeadForRef('refs/heads/' + branchName).then((_) {
      // TODO(Grv) : throw branch already exists.
      throw new GitException(GitErrorConstants.GIT_BRANCH_EXISTS);
    }, onError: (e) {
      return _getHeadRef(store, branchName, remoteBranchName).then(
          (String sha) {
        return store.createNewRef('refs/heads/' + branchName, sha).then((_) {
          Fetch fetch = new Fetch(options);
          return fetch.fetch();
        });
      });
    });
  }

  static Future<String> _getHeadRef(ObjectStore store, String branchName,
      String remoteBranchName) {
    if (remoteBranchName != null && remoteBranchName != "") {
      return store.getRemoteHeadForRef(remoteBranchName);
    } else {
      return store.getHeadRef().then((String headRefName) {
        return store.getHeadForRef(headRefName);
      });
    }
  }
}
