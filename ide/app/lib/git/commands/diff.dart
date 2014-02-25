// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.diff;

import 'dart:async';
import 'dart:typed_data';

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:crypto/crypto.dart' as crypto;

import '../constants.dart';
import '../file_operations.dart';
import '../http_fetcher.dart';
import '../object.dart';
import '../objectstore.dart';
import '../options.dart';
import '../pack.dart';
import '../pack_index.dart';
import '../upload_pack_parser.dart';
import '../utils.dart';
import 'index.dart';
import 'status.dart';

/**
 * A git diff command implementation.
 *
 * TODO add unittests.
*/

class Diff {

  static Future DiffFile(ObjectStore store, chrome.ChromeFileEntry entry) {
    return Status.getFileStatus(store, entry).then((FileStatus status) {
      if (status.headSha == status.sha) {
        // TODO(grv): throw error file is up-to-date.
        print('file unchanged');
        return new Future.error('file up-to-date');
      }

      return entry.readText().then((String content) {
        return store.retrieveObjectBlobsAsString([status.headSha]).then(
            (List<LooseObject> headObjects) {
          print(headObjects.first.data);
          print("===========");
          print(content);
          return new Future.value(content);
        });
      });
    });
  }
}
