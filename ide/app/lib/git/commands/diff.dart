// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.treediff;

import 'dart:async';

import 'constants.dart';
import 'index.dart';
import 'status.dart';
import '../object.dart';
import '../objectstore.dart';

/**
 * Implements tree diffs.
 *
 * TODO(grv): add unittests.
 */
class Diff {

  static Future<List<DiffResult>> diff(ObjectStore store) {
    return store.index.updateIndex().then((_) {
      List<DiffResult> diffs;
      Map<String, FileStatus> statuses = Status.getUnstagedChanges(store);
      return Future.forEach(statuses.keys, (String path) {
        FileStatus status = statuses[path];
        List<String> shas = [];
        if (status.headSha != null) shas.add(status.headSha);
        if (status.sha != null) shas.add(status.sha);
        if (shas.isEmpty) {
          // Ignore directoreis.
          return new Future.value();
        }
        return store.retrieveObjectBlobsAsString(shas).then(
            (List<LooseObject> files) {
          DiffResult diff;
          if (status.headSha == null) {
            // This file is added.
            diff = new DiffResult(status.path, status.headSha, status.sha, null,
                files.first.data, FileStatusType.ADDED);
          } else if (status.sha == null) {
            // This file is deleted.
            diff = new DiffResult(status.path, status.headSha, null,
                files.first.data,  null, FileStatusType.DELETED);
          } else {
            // This file is modified.
            diff = new DiffResult(status.path, status.headSha, status.sha,
                files.first.data,  files[1].data, FileStatusType.MODIFIED);
          }
        });
      }).then((_) => diffs);
    });
  }
}

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
