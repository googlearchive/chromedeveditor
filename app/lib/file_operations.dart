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

    Completer<chrome.Entry> completer = new Completer();

    root.createFile(path, exclusive: false).then((chrome.ChromeFileEntry entry) {
      //TODO(grv) : implement more general write function.
      entry.writeText(content).then((chrome.Entry entry) {
        completer.complete(entry);
      });
    });
    return completer.future;
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
    Completer completer = new Completer();
    chrome.DirectoryReader reader = root.createReader();
    List<chrome.Entry> entries = [];
    readEntries() {
      reader.readEntries().then((List<chrome.Entry> results) {
        if (!results.length){
          completer.complete(entries);
        } else {
          entries.addAll(results);
          readEntries();
        }
      }, onError: (e) {
        completer.completeError(e);
      });
    }
    readEntries();
    return completer.future;
  }
}
