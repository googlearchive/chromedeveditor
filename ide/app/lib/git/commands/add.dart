// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.add;

import 'dart:async';

import 'package:chrome/chrome_app.dart' as chrome;

import 'constants.dart';
import 'index.dart';
import 'status.dart';
import '../options.dart';

/**
 * This class implements the git add command.
 */
class Add {

  /**
   * Adds a given [entry] to git. A file already known to git is ignored.
   * Returns the updated status of the [entry].
   */
  static Future<FileStatus> addEntry(GitOptions options, chrome.Entry entry) {
    return Status.getFileStatus(options.store, entry).then((FileStatus status) {
      if (status.type == FileStatusType.UNTRACKED) {
        return FileStatus.createFromEntry(entry).then((FileStatus status) {
          status.type = FileStatusType.MODIFIED;
          return options.store.index.updateIndexForEntry(status);
        });
      } else {
        return status;
      }
    });
  }

  /**
   * Adds the given [entries] to git. A file is already known to git is ignored.
   * Returns the list of updates status of the entries.
   */
  static Future<List<FileStatus>> addEntries(GitOptions options,
      List<chrome.Entry> entries) {
    List<FileStatus> statuses = [];
    return Future.forEach(entries, (entry) {
      return addEntry(options, entry).then((status) {
        statuses.add(status);
      });
    }).then((_) => statuses);
  }
}
