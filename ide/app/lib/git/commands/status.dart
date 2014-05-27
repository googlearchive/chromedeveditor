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

  /**
   * Returns a map from the file path to the file status.
   */
  static Future<Map<String, FileStatus>> getFileStatuses(ObjectStore store) {
    return store.index.updateIndex().then((_) {
      return store.index.statusMap;
    });
  }

  /**
   * Return the status for an individual file entry.
   */
  static Future<FileStatus> getFileStatus(ObjectStore store,
      chrome.ChromeFileEntry entry) {
    return entry.getMetadata().then((chrome.Metadata data) {
      FileStatus status = store.index.getStatusForEntry(entry);
      if (status != null &&
          status.modificationTime == data.modificationTime.millisecondsSinceEpoch) {
        // Unchanged file since last update.
        return status;
      }

      // Dont't track status for new and untracked files unless explicitly
      // added.
      if (status == null) {

        status = new FileStatus();

        // Ignore status of .lock files.
        // TODO (grv) : Implement gitignore support.
        if (entry.name.endsWith('.lock')) {
          status.type = FileStatusType.COMMITTED;
        }
        return status;
      }

      // TODO(grv) : check the modification time when it is available.
      return getShaForEntry(entry, 'blob').then((String sha) {
        status = new FileStatus();
        status.path = entry.fullPath;
        status.sha = sha;
        status.size = data.size;
        status.modificationTime = data.modificationTime.millisecondsSinceEpoch;
        store.index.updateIndexForEntry(status);
        return store.index.getStatusForEntry(entry);
      });
    });
  }

  /**
   * Throws an exception if the working tree is not clean. Currently we do an
   * implicit 'git add' for all files in the tree. Thus, all changes in the tree
   * are treated as staged. We may want to separate the staging area for advanced
   * usage in the future.
   */
  static Future isWorkingTreeClean(ObjectStore store) {
    return _getFileStatusesForTypes(store, [FileStatusType.MODIFIED,
        FileStatusType.STAGED]).then((r) {
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

  static Future<List<String>> getDeletedFiles(ObjectStore store) {
    return _getFileStatusesForTypes(store, [FileStatusType.MODIFIED], false)
        .then(
        (Map<String, FileStatus> statuses) {
      List<String> deletedFilesStatus = [];
      statuses.forEach((String filePath, FileStatus status) {
        if (status.deleted) {
          deletedFilesStatus.add(filePath);
        }
      });
      return deletedFilesStatus;
    });
  }

  static Future<Map<String, FileStatus>> _getFileStatusesForTypes(
      ObjectStore store, List<String> types, [bool updateSha=true]) {
    return store.index.updateIndex(updateSha).then((_) {
      Map result = {};
      store.index.statusMap.forEach((k, v) {
        if (types.any((type) => v.type == type)) {
          result[k] = v;
        }
      });
      return result;
    });
  }
}
