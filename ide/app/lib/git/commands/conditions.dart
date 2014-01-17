// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.utils;

import 'dart:async';

import 'package:chrome/chrome_app.dart' as chrome;

import 'commit.dart';
import '../objectstore.dart';

class Conditions {

  static Future<GitConfig> checkForUncommittedChanges(chrome.DirectoryEntry dir,
      ObjectStore store) {

    return store.getHeadRef().then((String headRefName) {
      return store.getHeadForRef(headRefName).then((String parent) {
        return Commit.walkFiles(dir, store).then((String sha) {
          return Commit.checkTreeChanged(store, parent, sha).then((_) {
            // hasChanges true
          }, onError: (e) {
            if (e == "commits_no_changes")
              // hasChanges false
            else
              throw e;
          });
        });
      });
    });
  }

}
