// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.index;

import 'dart:async';
import 'dart:convert';

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:serialization/serialization.dart';

import 'constants.dart';
import '../file_operations.dart';
import '../objectstore.dart';
import '../utils.dart';

/**
 * This class implements git index. It reads the index file which saves the
 * meta data of the files in the repository. This data is used to find the
 * modified files in the working tree efficiently.
 *
 * TODO(grv) : Implement the interface.
 */
class Index {

  final ObjectStore _store;

  StatusMap _statusIdx = new StatusMap();

  Map<String, StatusEntry> get statusMap => _statusIdx.map;

  Index(this._store);

  Future updateIndexForEntry(StatusEntry status) {

    StatusEntry oldStatus = _statusIdx.map[status.path];

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
    _statusIdx.map[status.path] = status;
    return writeIndex();
  }

  Future commitEntry(StatusEntry status) {
    status.headSha = status.sha;
    status.type = FileStatusType.COMMITTED;
    _statusIdx.map[status.path] = status;
    return writeIndex();
  }

  StatusEntry getStatusForEntry(chrome.ChromeFileEntry entry)
      => _statusIdx.map[entry.fullPath];

  Future init() {
    return readIndex();
  }
  // TODO(grv) : remove this after index file implementation.
  Future _init() {
    return walkFilesAndUpdateIndex(_store.root).then((_) {
      _statusIdx.map.forEach((String key, StatusEntry status) {
        status.type = FileStatusType.COMMITTED;
        return writeIndex();
      });
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
    return _store.root.getDirectory(ObjectStore.GIT_FOLDER_PATH).then(
        (chrome.DirectoryEntry entry) {
      return entry.getFile('index2').then((chrome.ChromeFileEntry entry) {
        return entry.readText().then((String content) {
          JsonDecoder decoder = new JsonDecoder(null);
          var out = decoder.convert(content);
          var serialization = new Serialization();
          _statusIdx = serialization.read(out);
        });
      }, onError: (e) {
        return _init();
      });
    });
  }

  /**
   * Writes into the index file the current index.
   */
  Future writeIndex() {
    var serialization = new Serialization();
    var output = serialization.write(_statusIdx);
    var serialization2 = new Serialization();

    JsonEncoder encoder = new JsonEncoder();
    String out = encoder.convert(output);

    return _store.root.getDirectory(ObjectStore.GIT_FOLDER_PATH).then(
        (chrome.DirectoryEntry entry) {
      return FileOps.createFileWithContent(entry, 'index2', out, 'Text');
    });
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
              StatusEntry status = new StatusEntry();
              status.path = entry.fullPath;
              status.sha = sha;
              status.size = data.size;
               return updateIndexForEntry(status);
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

  StatusEntry();

  /**
   * Return true if the [entry] is same as [this].
   */
  bool compareTo(StatusEntry entry) =>
    (entry.path == path && entry.sha == sha && entry.size == size);
}

class StatusMap {
  Map<String,StatusEntry> map = {};
}
