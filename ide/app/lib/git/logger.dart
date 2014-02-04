// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.logger;

import 'dart:async';

import 'package:chrome/chrome_app.dart' as chrome;

import 'constants.dart';
import 'file_operations.dart';
import 'options.dart';
import 'utils.dart';

/**
 * Logs the git commands. These logs are consumend in restoring git state.
 */
class Logger {

  static Future log(GitOptions options, String fromSha, String toSha,
      String message) {
    String dateString = getCurrentTimeAsString();
    String logString = [fromSha, toSha, options.username, '<${options.email}}>',
        dateString, message].join(" ");
    logString += '\n';
    String path = '${LOGS_DIR}HEAD';
    return options.root.createDirectory(path).then(
        (chrome.ChromeFileEntry entry) {
      return entry.readText().then((String text) {
        return FileOps.createFileWithContent(options.root, path,
            text + logString, 'Text');
      });
    });
  }

  static Future _createAndGetFile(chrome.DirectoryEntry root, String path) {
    return root.getFile(path).then((entry) => entry)
      .catchError((e) {
      return FileOps.createFileWithContent(root, path, '', 'Text');
    });
  }
}
