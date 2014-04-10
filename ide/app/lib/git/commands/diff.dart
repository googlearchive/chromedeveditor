// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.diff;

import 'dart:async';
import 'dart:js' as js;

import 'package:chrome/chrome_app.dart' as chrome;

import '../object.dart';
import '../objectstore.dart';
import 'index.dart';
import 'status.dart';

/**
 * A git diff command implementation.
 *
 * TODO add unittests.
*/

class Diff {

  /**
   * Returns a list containing content of head version, current version of the
   * given file entry.
   */
  static Future<List<String>> DiffFile(ObjectStore store,
      chrome.ChromeFileEntry entry) {
    return Status.getFileStatus(store, entry).then((FileStatus status) {
      if (status.headSha == status.sha) {
        // Should we throw an error here ?
        //return new Future.error('file up-to-date');
      }

      return entry.readText().then((String content) {
        return store.retrieveObjectBlobsAsString([status.headSha]).then(
            (List<LooseObject> headObjects) {
          return new Future.value([headObjects[0].data, content]);
        });
      });
    });
  }
}
