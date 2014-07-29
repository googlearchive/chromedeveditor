// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.filesystem;

import 'dart:async';

import 'package:chrome/chrome_app.dart' as chrome;

import '../spark.dart';
import 'workspace.dart' as ws;

/**
 * Provides an abstracted access to the filesystem
 */
class FileSystemAccess {
  static FileSystemAccess _instance;

  ws.WorkspaceRoot _root;
  ws.WorkspaceRoot get root {
    if (_root == null) {
      if (_location.isSync) {
        _root = new ws.SyncFolderRoot(_location.entry);
      } else {
        _root = new ws.FolderChildRoot(_location.parent, _location.entry);
      }
    }

    return _root;
  }

  void setRoot(ws.WorkspaceRoot root) {
    assert(_root == null);
    _root = root;
  }

  LocationResult _location;
  void set location(LocationResult location) {
    _location = location;
  }


  static FileSystemAccess get instance {
    if (_instance == null) _instance = new FileSystemAccess._internal();
    return _instance;
  }

  FileSystemAccess._internal();

  Future<String> getDisplayPath(chrome.Entry entry) {
    return chrome.fileSystem.getDisplayPath(entry);
  }

  restoreManager(Spark spark) {
    return ProjectLocationManager.restoreManager(spark);
  }
}
