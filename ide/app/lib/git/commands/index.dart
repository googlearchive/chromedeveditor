// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.index;

import 'dart:async';
import 'dart:convert';

import 'package:chrome/chrome_app.dart' as chrome;

import 'constants.dart';
import '../constants.dart';
import '../exception.dart';
import '../file_operations.dart';
import '../objectstore.dart';
import '../permissions.dart';
import '../utils.dart';

/**
 * This class implements git index. It reads the index file which saves the
 * meta data of the files in the repository. This data is used to find the
 * modified files in the working tree efficiently.
 *
 * TODO(grv): Implement the interface.
 */
class Index {

  final ObjectStore _store;
  Map<String, FileStatus> _statusIdx = {};
  Map<String, FileStatus> get statusMap => _statusIdx;
  // Whether index needs to be written on disk.
  bool _indexDirty = false;
  // Whether the index is being written on disk.
  bool _writingIndex = false;
  // The timer used to schedule saving of the index to the disk.
  Timer _writeIndexTimer;
  // When the index is being written, it's the completer used internally
  // to know when it will complete.
  Completer _writeIndexCompleter = null;
  // Request to write the index to disk now is in progress.
  bool _flushing = false;

  Index(this._store);

  void deleteIndexForEntry(String path) {
    if (_statusIdx.containsKey(path)) {
      _statusIdx.remove(path);
    }
  }

  /**
   * Creats a index entry for a given [status]. If entry already exists delete
   * and create a new entry.
   */
  void createIndexForEntry(FileStatus status) {
    deleteIndexForEntry(status.path);
    status.type = FileStatusType.COMMITTED;
    updateIndexForFile(status);
  }

  void updateIndexForEntry(chrome.Entry entry, FileStatus status) {
    if (entry.isDirectory) {
      _statusIdx[status.path] = status;
    } else {
      updateIndexForFile(status);
    }
  }

  void updateIndexForFile(FileStatus status) {
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
          default:
            throw new GitException(GitErrorConstants.GIT_FILE_STATUS_TYPE_UNKNOWN,
                "Unknown file status type: ${oldStatus.type}");
        }
      } else {
        status.type = oldStatus.type;
      }
    }
    _statusIdx[status.path] = status;
    _scheduleWriteIndex();
  }

  /**
   * Updates the git index. Status of deleted files are removed.
   * Status of untracked files are left as untracked.
   */
  Future onCommit() {
    Map<String, FileStatus> statusIdx = {};
    _statusIdx.forEach((key, FileStatus status) {
      if (status.type != FileStatusType.UNTRACKED) {
        status.headSha = status.sha;
        status.type = FileStatusType.COMMITTED;
      }
      if (status.deleted == false) {
        statusIdx[key] = status;
      }
    });
    _statusIdx = statusIdx;
    _scheduleWriteIndex();
    return updateIndex();
  }

  FileStatus getStatusForEntry(chrome.Entry entry)
      => _statusIdx[entry.fullPath];

  Future init() {
    return readIndex();
  }

  // TODO(grv): Remove this after index file implementation.
  void reset([bool isFirstRun]) {
      _statusIdx.forEach((String key, FileStatus status) {
        if (status.type != FileStatusType.UNTRACKED || isFirstRun != null) {
          status.type = FileStatusType.COMMITTED;
        }
        status.headSha = status.sha;
      });
      _scheduleWriteIndex();
  }

  Future updateIndex([bool updateSha=true]) {
    return walkFilesAndUpdateIndex(_store.root, updateSha).then(
        (List<FileStatus> statuses) {
      _updateDeletedFiles(statuses);
      return new Future.value();
    });
  }

  /**
   * Reads the index file and loads it.
   */
  Future readIndex() {
    return _store.root.getDirectory(GIT_FOLDER_PATH).then(
        (chrome.DirectoryEntry entry) {
      return entry.getFile('index2').then((chrome.ChromeFileEntry entry) {
        return entry.readText().then((String content) {
          JsonDecoder decoder = new JsonDecoder(null);
          Map out = decoder.convert(content);
          _statusIdx = _parseIndex(out);
        });
      }, onError: (e) {
        reset(true);
        return new Future.value();
      });
    });
  }

  /**
   * Writes into the index file the current index.
   */
  Future _writeIndex() {
    assert(_writeIndexCompleter == null);
    _writingIndex = true;
    _writeIndexCompleter = new Completer();
    String out = JSON.encode(statusIdxToMap());
    return _store.root.getDirectory(GIT_FOLDER_PATH).then(
        (chrome.DirectoryEntry entry) {
      return FileOps.createFileWithContent(entry, 'index2', out, 'Text')
          .then((_) {
        Completer completer = _writeIndexCompleter;
        _writeIndexCompleter = null;
        _writingIndex = false;
        completer.complete();
      });
    });
  }

  /**
   * Schedule saving of the index to the disk.
   */
  void _scheduleWriteIndex() {
    _indexDirty = true;

    if (_writingIndex) {
      return;
    }

    if (_writeIndexTimer != null) {
      _writeIndexTimer.cancel();
      _writeIndexTimer = null;
    }

    _writeIndexTimer = new Timer(const Duration(seconds: 2), () {
      _writeIndexTimer = null;
      _indexDirty = false;
      _writeIndex().then((_) {
        if (_indexDirty && !_flushing) {
          _scheduleWriteIndex();
        }
      });
    });
  }

  /**
   * Flush the index to disk now and returns a Future if the caller needs to
   * wait for completion.
   */
  Future flush() {
    if (_writingIndex) {
      // Waiting for completion...
      assert(_writeIndexCompleter != null);
      _flushing = true;
      return _writeIndexCompleter.future.then((_) {
        // Then write the index if needed.
        if (_indexDirty) {
          _indexDirty = false;
          return _writeIndex().then((_) {
            _flushing = false;
          });
        }
      });
    } else {
      if (!_indexDirty) {
        // Doesn't need to write the index.
        return new Future.value();
      }

      if (_writeIndexTimer != null) {
        _writeIndexTimer.cancel();
        _writeIndexTimer = null;
      }
      _flushing = true;
      return _writeIndex().then((_) {
        _flushing = false;
      });
    }
  }

  /**
   * Walks over all the files in the working tree. Returns status of the
   * working tree.
   */
   Future<List<FileStatus>> walkFilesAndUpdateIndex(chrome.DirectoryEntry root,
       bool updateSha) {
     List<FileStatus> fileStatuses = [];
     return FileOps.listFiles(root).then(
         (List<chrome.ChromeFileEntry> entries) {
       if (entries.isEmpty) {
         deleteIndexForEntry(root.fullPath);
         return fileStatuses;
       }

       return Future.forEach(entries, (chrome.Entry entry) {
         if ((_store.root.fullPath + '.git') == entry.fullPath) {
           return fileStatuses;
         }

         if (entry.isDirectory) {
           return walkFilesAndUpdateIndex(entry, updateSha).then((statuses) {
             fileStatuses.addAll(statuses);
           });
         } else {
           // don't update index for untracked files.
           if (_statusIdx[entry.fullPath] != null) {
             fileStatuses.add(_statusIdx[entry.fullPath]);
             if (updateSha) {
               return _updateSha(entry);
             }
           }
         }
       }).then((_) {
         if (fileStatuses.isEmpty) {
           deleteIndexForEntry(root.fullPath);
         } else if (fileStatuses.any((status) => status.type
             != FileStatusType.COMMITTED)) {
           FileStatus status = FileStatus.createForDirectory(root);
           status.type = FileStatusType.MODIFIED;
           _statusIdx[root.fullPath] = status;
           fileStatuses.add(status);
         } else {
           FileStatus status = FileStatus.createForDirectory(root);
           status.type = FileStatusType.COMMITTED;
           status.path = root.fullPath;
           _statusIdx[root.fullPath] = status;
           fileStatuses.add(status);
         }
         return fileStatuses;
       });
     });
   }

   Future _updateSha(chrome.FileEntry entry) {
     FileStatus status = _statusIdx[entry.fullPath];
     return entry.getMetadata().then((data) {
       if (status.modificationTime == data.modificationTime.millisecondsSinceEpoch) {
         return new Future.value();
       } else {
         return getShaForEntry(entry, 'blob').then((String sha) {
           FileStatus newStatus = new FileStatus()
               ..path = entry.fullPath
               ..sha = sha
               ..size = data.size
               ..modificationTime = data.modificationTime.millisecondsSinceEpoch
               ..permission = status.permission;
           updateIndexForFile(newStatus);
         });
       }
     });
   }

  /**
   * Update the index saving the information for deleted files. If the files
   * are added back, they will be restored back and not treated as untracked.
   */
  void _updateDeletedFiles(List<FileStatus> statuses) {
    List<String> filePaths = statuses.map((status) => status.path).toList();
    _statusIdx.forEach((String filePath, FileStatus status) {
      if (!filePaths.contains(filePath)) {
        status.deleted = true;
        status.sha = null;
        status.type = FileStatusType.MODIFIED;
      }
    });
  }

  Map<String, FileStatus> _parseIndex(Map m) {
    Map<String, FileStatus> result = {};
    m.forEach((String key, Map statusMap) {
      FileStatus status = new FileStatus();
      status.headSha = statusMap['headSha'];
      status.sha = statusMap['sha'];
      status.modificationTime = statusMap['modificationTime'];
      status.permission = statusMap['permission'];
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
  String permission;
  String sha;
  int size;
  bool deleted = false;

  /**
   * The number of milliseconds since the Unix epoch.
   */
  int modificationTime;

  /**
   * [type] is one of [FileStatusType].
   */
  String type;

  FileStatus() {
    this.type = FileStatusType.UNTRACKED;
    this.permission = Permissions.FILE_NON_EXECUTABLE;
  }

  static FileStatus createFromEntry(chrome.Entry entry) {
    FileStatus status = new FileStatus();
    status.path = entry.fullPath;
    status.sha = '';
    // TODO(grv): Read real file permissions from metadata when available.
    status.permission = Permissions.FILE_NON_EXECUTABLE;
    return status;
  }

  static FileStatus createForDirectory(chrome.Entry entry) {
    FileStatus status = new FileStatus();
    status.path = entry.fullPath;
    status.permission = Permissions.DIRECTORY;
    return status;
  }

  FileStatus.fromMap(Map m) {
    path = m['path'];
    headSha = m['headSha'];
    sha = m['sha'];
    size = m['size'];
    modificationTime = m['modificationTime'];
    permission = m['permission'];
    type = m['type'];
    deleted = m['deleted'];
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
      'permission': permission,
      'type' : type,
      'deleted' : deleted
    };
  }

  String toString() => '[${path} ${type}]';
}
