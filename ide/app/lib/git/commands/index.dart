// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.index;

import 'dart:async';
import 'dart:convert';

import 'package:chrome/chrome_app.dart' as chrome;

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

  Map<String, FileStatus> _statusIdx = {};

  Map<String, FileStatus> get statusMap => _statusIdx;

  Index(this._store);

  Future updateIndexForEntry(FileStatus status) {

    FileStatus oldStatus = _statusIdx[status.path];

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
    return writeIndex();
  }

  Future commitEntry(FileStatus status) {
    status.headSha = status.sha;
    status.type = FileStatusType.COMMITTED;
    _statusIdx[status.path] = status;
    return writeIndex();
  }

  FileStatus getStatusForEntry(chrome.Entry entry)
      => _statusIdx[entry.fullPath];

  Future init() {
    return readIndex();
  }

  // TODO(grv) : remove this after index file implementation.
  Future _init() {
    return walkFilesAndUpdateIndex(_store.root).then((_) {
      _statusIdx.forEach((String key, FileStatus status) {
        status.type = FileStatusType.COMMITTED;
        return writeIndex();
      });
    });
  }

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
          Map out = decoder.convert(content);
          _statusIdx = _parseIndex(out);
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

    JsonEncoder encoder = new JsonEncoder();
    String out = encoder.convert(statusIdxToMap());

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
     return FileOps.listFiles(root).then((List<chrome.ChromeFileEntry> entries) {
       if (entries.isEmpty) {
         return new Future.value();
       }

       return Future.forEach(entries, (chrome.Entry entry) {
         if (entry.name == '.git') {
           return new Future.value();
         }

         if (entry.isDirectory) {
           return walkFilesAndUpdateIndex(entry as chrome.DirectoryEntry).then((String sha) {
             return new Future.value();
           });
         } else {
           return getShaForEntry(entry, 'blob').then((String sha) {
             return entry.getMetadata().then((data) {
               FileStatus status = new FileStatus();
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

  Map<String, FileStatus> _parseIndex(Map m) {
    Map<String, FileStatus> result = {};
    m.forEach((String key, Map statusMap) {
      FileStatus status = new FileStatus();
      status.headSha = statusMap['headSha'];
      status.sha = statusMap['sha'];
      status.modificationTime = statusMap['modificationTime'];
      status.path = statusMap['path'];
      status.size = statusMap['size'];
      status.type = statusMap['type'];
      result[key] = status;
    });
    return result;
  }

  Map statusIdxToMap() {
    Map m = {};
    _statusIdx.forEach((String key, FileStatus status) {
      m[key] = status.toMap();
    });
    return m;
  }
}

/**
 * Represents the metadata of a file used to identify if the file is
 * modified or not.
 */
class FileStatus {
  String path;
  String headSha;
  String sha;
  int size;
  int modificationTime;
  String type;

  FileStatus();

  FileStatus.fromMap(Map m) {
    path = m['path'];
    headSha = m['headSha'];
    sha = m['sha'];
    size = m['size'];
    modificationTime = m['modificationTime'];
    type = m['type'];
  }

  /**
   * Return true if the [entry] is same as [this].
   */
  bool compareTo(FileStatus status) =>
    (status.path == path && status.sha == sha && status.size == size);

  Map toMap() {
    return {
      'path': path,
      'headSha': headSha,
      'sha' : sha,
      'size' : size,
      'modificationTime' : modificationTime,
      'type' : type
    };
  }
}
