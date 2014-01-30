// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.status;

import 'dart:async';

import 'package:chrome/chrome_app.dart' as chrome;

import 'constants.dart';
import 'index.dart';
import '../objectstore.dart';
import '../utils.dart';

class Status {

  static Future<Map<String, FileStatus>> getFileStatuses(ObjectStore store) {
    return store.index.updateIndex().then((_) {
      return store.index.statusMap;
    });
  }

  static Future<FileStatus> getFileStatus(ObjectStore store,
      chrome.ChromeFileEntry entry) {
    Completer completer = new Completer();
    entry.getMetadata().then((data) {
      // TODO(grv) : check the modification time when it is available.
      getShaForEntry(entry, 'blob').then((String sha) {
        FileStatus status = new FileStatus();
        status.path = entry.fullPath;
        status.sha = sha;
        status.size = data.size;
        store.index.updateIndexForEntry(status);
        completer.complete(store.index.getStatusForEntry(entry));
      });
    });
    return completer.future;
  }

  /**
   * Throws an exception if the working tree is not clean. Currently we do an
   * implicit 'git add' for all files in the tree. Thus, all changes in the tree
   * are treated as staged. We may want to separate the staging area for advanced
   * usage in the future.
   */
  static Future isWorkingTreeClean(ObjectStore store) {
    return _getFileStatusesForTypes(store, [FileStatusType.MODIFIED,
        FileStatusType.STAGED, FileStatusType.UNTRACKED]).then((r) {
      if (!r.isEmpty) {
        //TODO(grv) : throw custom exception.
        throw "Uncommitted changes in the working tree.";
      }
    });
  }

  static Future<Map<String, FileStatus>> getUnstagedChanges(ObjectStore store)
      => _getFileStatusesForTypes(store, [FileStatusType.MODIFIED]);

  static Future<Map<String, FileStatus>> getStagedChanges(ObjectStore store)
      => _getFileStatusesForTypes(store, [FileStatusType.STAGED]);

  static Future<Map<String, FileStatus>> getUntrackedChanges(ObjectStore store)
      => _getFileStatusesForTypes(store, [FileStatusType.UNTRACKED]);

  static Future<Map<String, FileStatus>> _getFileStatusesForTypes(
      ObjectStore store, List<String> types) {
    return store.index.updateIndex().then((_) {
      Map result = {};
      store.index.statusMap.forEach((k,v) {
        if (types.any((type) => v.type == type)) {
          result[k] = v;
        }
      });
      return result;
    });
  }
}
