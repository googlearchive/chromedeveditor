// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.file_operations;

import 'dart:async';
import 'dart:core';

import 'package:chrome_gen/chrome_app.dart' as chrome;

/**
 * Utility class to access HTML5 filesystem operations.
 * TODO(grv): Add unittests.
 *
 **/
abstract class FileOps {

  static Future<chrome.Entry> createFileWithContent(
      chrome.DirectoryEntry root, String path, content, String type) {

    root.createFile(path).then((chrome.ChromeFileEntry entry) {
      //TODO(grv) : implement more general write function.
      return entry.writeText(content).then((_) => entry);
    });
  }

  static Future<dynamic> readFile(chrome.DirectoryEntry root, String path,
      String type) {
    Completer<String> completer = new Completer();
    root.getFile(path).then((chrome.ChromeFileEntry entry) {
      //TODO(grv): Implement a general read function, supporting different
      // formats.
      entry.readText().then((String content){
        completer.complete(content);
      });

    });
    return completer.future;
  }

  /**
   * Lists the files in a given [root] directory.
   */
  static Future<List<chrome.Entry>> listFiles(chrome.DirectoryEntry root) {
    return root.createReader().readEntries();
  }
}