// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.status;

import 'dart:async';

import 'package:chrome/chrome_app.dart' as chrome;

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
}
