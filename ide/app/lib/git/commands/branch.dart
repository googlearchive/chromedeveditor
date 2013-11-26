// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.branch;

import 'dart:async';
import 'dart:html';

import '../git.dart';
import '../objectstore.dart';

class Branch {

  bool _verifyBranchName(String name) {
    var length = name.length;
    var branchRegex = new RegExp(
        "^(?!/|.*([/.]\\.|//|@\\{|\\\\))[^\\x00-\\x20 ~^:?*\\[]+\$");
    if (name.isNotEmpty && name.matchAsPrefix(name).groupCount) {
      if ((length < 5 || name.lastIndexOf('.lock') != length - 5) &&
          name[length -1] != '.' && name[length - 1] != '/'
          && name[0] != '.') {
        return true;
      }
    }
    return false;
  }

  /**
   * Creates a new branch. Throws error if the branch already exist.
   */
  Future branch(GitOptions options) {
    ObjectStore store = options.store;
    String branchName = options.branchName;

    if (!_verifyBranchName(branchName)) {
      // TODO(grv) throw error.
      return null;
    }

    return store.getHeadForRef('refs/heads/' + branchName).then((_) {
      // TODO(Grv) : throw branch already exists.
    }, onError: (e) {
      if (e.code == FileError.NOT_FOUND_ERR) {
        return store.getHeadRef().then((String refName) {
          return store.getHeadForRef(refName).then((String sha) {
            return store.createNewRef('refs/heads/' + branchName, sha);
          });
        });
      } else {
        throw e;
      }
    });
  }
}