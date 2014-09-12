// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.diff;

import 'dart:async';

import 'constants.dart';
import 'index.dart';
import 'status.dart';
import '../file_operations.dart';
import '../object.dart';
import '../objectstore.dart';

/**
 * Implements git diff command.
 *
 * TODO(grv): add unittests.
 */
class Diff {

  static Future<List<DiffResult>> diff(ObjectStore store) {
    return store.index.updateIndex().then((_) {

      List<DiffResult> diffs = [];
      Map<String, FileStatus> statuses = Status.getUnstagedChanges(store);
      return Future.forEach(statuses.keys, (String path) {

        FileStatus status = statuses[path];
        String currentSha = status.sha;
        String headSha = status.headSha;

        if (currentSha == null && headSha == null) {
          // Ignore directories.
          return new Future.value();
        }

        return _retrieveShas(store, status.path, status.headSha, status.sha).then(
            (Map<String, String> contentMap){
          DiffResult diff;
          if (headSha == null) {
            // This file is added.
            diff = new DiffResult(status.path, null, currentSha, null,
                contentMap[currentSha], FileStatusType.ADDED);
          } else if (currentSha == null) {
            // This file is deleted.
            diff = new DiffResult(status.path, headSha, null, contentMap[headSha],
                null, FileStatusType.DELETED);
          } else {
            // This file is modified.
            diff = new DiffResult(status.path, headSha, currentSha, contentMap[headSha],
                contentMap[currentSha], FileStatusType.MODIFIED);
          }
          diffs.add(diff);
        });
      }).then((_) => diffs);
    });
  }

  static Future<Map<String, String>> _retrieveShas(
      ObjectStore store, String path, String headSha, String currentSha) {
    Map<String, String> contentMap = {};
    if (headSha == null && currentSha == null) {
      return new Future.value(contentMap);
    }
    return new Future(() {
      if (headSha != null) {
        return store.retrieveObjectBlobsAsString([headSha]).then(
            (List<LooseObject> looseObj) {
          contentMap[headSha] = looseObj.first.data;
        });
      }
    }).then((_) {
      if (currentSha != null) {
        return FileOps.readFileText(store.root, path).then((String content) {
          contentMap[currentSha] = content;
        });
      } else {
        return new Future.value();
      }
    }).then((_) => contentMap);
  }
}

/**
 * A dataType to hold diff information of a file.
 */
class DiffResult {
  final String path;
  final String oldSha;
  final String newSha;
  final String oldContent;
  final String newContent;
  final String status;
  String diffContent;

  DiffResult(this.path, this.oldSha, this.newSha, this.oldContent,
      this.newContent, this.status, [this.diffContent=null]) {

  }
}
