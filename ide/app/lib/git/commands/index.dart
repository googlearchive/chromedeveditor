// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.index;

import 'dart:async';
import 'dart:typed_data';

import 'dart:html';

import 'package:chrome/chrome_app.dart' as chrome;

import 'constants.dart';
import '../file_operations.dart';
import '../objectstore.dart';
import '../utils.dart';

/**
 * This class implements git index. It reads the index file which saves the
 * meta data of the files in the repository. This data is used to find the
 * modified files efficiently.
 *
 * TODO(grv) : Implment the interface.
 */
class Index {

  ObjectStore _store;

  Map<String, StatusEntry> _statusIdx = {};

  get statusMap => _statusIdx;

  Index(this._store);

  void updateIndexForEntry(StatusEntry status) {

    StatusEntry oldStatus = _statusIdx[status.path];

    if (oldStatus != null) {
      status.headSha = oldStatus.headSha;

      if (!status.compareTo(oldStatus)) {
        switch(oldStatus.type) {
          case FileStatusType.COMMITTED:
            status.type = FileStatusType.MODIFIED;
            break;
          case FileStatusType.STAGED:
            if (status.headSha != status.sha){
              status.type = FileStatusType.STAGED;
            } else {
              status.type = FileStatusType.COMMITTED;
            }
            break;
          case FileStatusType.MODIFIED:
            if (status.headSha != status.sha){
              status.type = FileStatusType.MODIFIED;
            } else {
              status.type = FileStatusType.COMMITTED;
            }
            break;
          case FileStatusType.UNTRACKED:
            status.type = FileStatusType.UNTRACKED;
            break;
          default:
            throw "Unsupported file status type.";
        }
      } else {
        status.type = oldStatus.type;
      }
    } else {
      status.headSha = status.sha;
      status.type = FileStatusType.UNTRACKED;
    }
    _statusIdx[status.path] = status;
  }

  void commitEntry(StatusEntry status) {
    status.headSha = status.sha;
    status.type = FileStatusType.COMMITTED;
    _statusIdx[status.path] = status;
  }

  StatusEntry getStatusForEntry(chrome.ChromeFileEntry entry)
      => _statusIdx[entry.fullPath];

  // TODO(grv) : remove this after index file implementation.
  Future init() {
    return walkFilesAndUpdateIndex(_store.root).then((_) {
      _statusIdx.forEach((String key, StatusEntry status) {
        status.type = FileStatusType.COMMITTED;

        return new Future.value();
      });
      print('successfully update index.');
    });
  }

  // TODO(grv) : This is temporary. It should read the index file instead.
  Future updateIndex() {
    return walkFilesAndUpdateIndex(_store.root);
  }

  /**
   * Reads the index file and loads it.
   */
  Future readIndex() {
    return null;
  }

  /**
   * Writes into the index file the current index.
   */
  Future writeIndex() {
    return null;
  }

  /**
   * Walks over all the files in the working tree. Returns sha of the
   * working tree.
   */
   Future<String> walkFilesAndUpdateIndex(chrome.DirectoryEntry root) {

    return FileOps.listFiles(root).then(
        (List<chrome.ChromeFileEntry> entries) {
      if (entries.isEmpty) {
        return new Future.value();
      }

      return Future.forEach(entries, (chrome.ChromeFileEntry entry) {
        if (entry.name == '.git') {
          return new Future.value();
        }

        if (entry.isDirectory) {
          return walkFilesAndUpdateIndex(entry as chrome.DirectoryEntry)
              .then((String sha) {
                return new Future.value();
          });
        } else {
          return getShaForEntry(entry, 'blob').then((String sha) {
            return entry.getMetadata().then((data) {
              StatusEntry status = new StatusEntry(entry.fullPath, sha,
                  data.size);
               updateIndexForEntry(status);
               return new Future.value();
            });
          });
        }
      }).then((_) {
        return new Future.value();
      });
    });
  }
}

/**
 * Represents the metadata of a file used to identify if the file is
 * modified or not.
 */
class StatusEntry {
  String path;
  String headSha;
  String sha;
  int size;
  int modificationTime;
  String type;

  StatusEntry(this.path, this.sha, this.size);

  /**
   * Return true if the [entry] is same as [this].
   */
  bool compareTo(StatusEntry entry) =>
    (entry.path == path && entry.sha == sha && entry.size == size);
}