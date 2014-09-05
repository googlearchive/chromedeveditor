// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.status;

import 'dart:async';

import 'package:chrome/chrome_app.dart' as chrome;

import 'constants.dart';
import 'ignore.dart';
import 'index.dart';
import '../exception.dart';
import '../file_operations.dart';
import '../objectstore.dart';
import '../utils.dart';

class Status {

  /**
   * Returns a map from the file path to the file status.
   */
  static Future<Map<String, FileStatus>> getFileStatuses(ObjectStore store) {
    return store.index.updateIndex(true).then((_) {
      return store.index.statusMap;
    });
  }

  static FileStatus getStatusForEntry(ObjectStore store, chrome.Entry entry) {
    FileStatus status = store.index.getStatusForEntry(entry);

    // untracked file.
    if (status == null) {
      status = new FileStatus();

      if (GitIgnore.ignore(entry.fullPath)) {
        status.type = FileStatusType.COMMITTED;
      }
    }

    return status;
  }

  /**
   * Update and return the status for an individual file entry.
   */
  static Future<FileStatus> updateAndGetStatus(ObjectStore store,
      chrome.Entry entry) {
    FileStatus status;

    return entry.getMetadata().then((chrome.Metadata data) {
      status = getStatusForEntry(store, entry);

      if (status.type == FileStatusType.UNTRACKED || entry.isDirectory) {
        return status;
      }

      // Don't update status for files ignored by git.
      if (GitIgnore.ignore(entry.fullPath)) {
        return status;
      }

      if (status.modificationTime
          == data.modificationTime.millisecondsSinceEpoch) {
        // Unchanged file since last update.
        return status;
      }

      return getShaForEntry(entry, 'blob').then((String sha) {
        FileStatus newStatus = new FileStatus()
            ..path = entry.fullPath
            ..sha = sha
            ..size = data.size
            ..permission = status.permission
            ..modificationTime = data.modificationTime.millisecondsSinceEpoch;
        store.index.updateIndexForFile(newStatus);
        return newStatus;
      });
    }).then((_) {
      if (status.type != FileStatusType.UNTRACKED) {
        return _updateParent(store, entry).then((_) => status);
      } else {
        return status;
      }
    });
  }

  static Future _updateParent(ObjectStore store, chrome.Entry entry) {
    if (entry.fullPath == store.root.fullPath) {
      return new Future.value();
    }

    // Don't update status for .git folder and sub-folders.
    if (entry.fullPath.startsWith(store.root.fullPath + '/.git')) {
      return new Future.value();
    }

    return entry.getParent().then((chrome.DirectoryEntry root) {
      return FileOps.listFiles(root).then((entries) {
        bool isChanged = entries.any((entry) => getStatusForEntry(store,
            entry).type == FileStatusType.MODIFIED);
        FileStatus status = FileStatus.createForDirectory(root);
        if (isChanged) {
          status.type = FileStatusType.MODIFIED;
        } else {
          status.type = FileStatusType.COMMITTED;
        }
        store.index.updateIndexForEntry(root, status);
        if (root.fullPath != store.root.fullPath) {
          return _updateParent(store, root);
        }
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

    return store.index.updateIndex(true).then((_) {
      Map<String, FileStatus> statuses = _getFileStatusesForTypes(store,
          [FileStatusType.MODIFIED, FileStatusType.STAGED]);
      if (statuses.isNotEmpty) {
        throw new GitException(GitErrorConstants.GIT_WORKING_TREE_NOT_CLEAN);
      }
    });
  }

  static Map<String, FileStatus> getUnstagedChanges(ObjectStore store)
      => _getFileStatusesForTypes(store, [FileStatusType.MODIFIED]);

  static Map<String, FileStatus> getStagedChanges(ObjectStore store)
      => _getFileStatusesForTypes(store, [FileStatusType.STAGED]);

  static Map<String, FileStatus> getUntrackedChanges(ObjectStore store)
      => _getFileStatusesForTypes(store, [FileStatusType.UNTRACKED]);

  static Future<List<String>> getDeletedFiles(ObjectStore store) {
    return store.index.updateIndex(false).then((_) {
      List<String> deletedFilesStatus = [];
      store.index.statusMap.forEach((path, status) {
        if (status.type == FileStatusType.MODIFIED && status.deleted) {
          deletedFilesStatus.add(path);
        }
      });
      return deletedFilesStatus;
    });
  }

  static Map<String, FileStatus> _getFileStatusesForTypes(
      ObjectStore store, List<String> types, [bool updateSha=true]) {
    Map result = {};
    store.index.statusMap.forEach((k, v) {
      if (types.any((type) => v.type == type)) {
        result[k] = v;
      }
    });
    return result;
  }
}
