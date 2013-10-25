// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.objectstore;

import 'dart:async';
import 'dart:core';

import 'package:chrome_gen/chrome_app.dart' as chrome;

import 'file_operations.dart';

/**
 * An objectstore for git objects.
 * TODO(grv): Add unittests, add better docs.
 **/
class ObjectStore {

  static final GIT_FOLDER_PATH = '.git/';
  static final GIT_OBJECT_FOLDER_PATH = '.git/objects';
  static final GIT_HEAD_PATH = '.git/HEAD';

  // The root directory of the git checkout the objectstore represents.
  chrome.DirectoryEntry _rootDir;

  // The root directory of the objects the objectstore represnts.
  chrome.DirectoryEntry _objectDir;

  //TODO(grv) : Expose pack , packIdx as dart and add type here.
  List<dynamic> _packs = [];

  ObjectStore(chrome.DirectoryEntry root) {
    _rootDir = root;

  }

  loadWith(chrome.DirectoryEntry objectDir, List<dynamic> packs) {
    _objectDir = objectDir;
    _packs = packs;
  }

  Future load() {
    chrome.DirectoryEntry rootDir = _rootDir;
    Completer completer = new Completer();

    rootDir.createDirectory(GIT_OBJECT_FOLDER_PATH, exclusive: false).then((
        chrome.DirectoryEntry objectsDir) {

      _objectDir = objectsDir;

      objectsDir.createDirectory('pack', exclusive: true).then((
          chrome.DirectoryEntry packDir) {

        List<chrome.Entry> packEntries = [];

        chrome.DirectoryReader reader = packDir.createReader();
        readEntries() {

          reader.readEntries().then((List<chrome.Entry> entries) {
            if (entries.length != 0) {
              entries.forEach((chrome.Entry entry) {
                if (entry.name.endsWith('.pack'))
                  packEntries.add(entry);

              });

              readEntries();
            } else {
              if (packEntries.length != 0) {
                List<Future> packReadFutures;
                return Future.forEach(packEntries, (chrome.Entry entry) {
                  _readPackEntry(packDir, entry);
                });
              } else {
                completer.complete();
              }
            }
          });
        }
        readEntries();
      }, onError: (e) {
        completer.complete(e);

      });
    }, onError: (e) {
      completer.complete(e);

    });
    return completer.future;
  }

  Future<chrome.FileEntry> createNewRef(String refName, String sha) {
    String path = GIT_FOLDER_PATH + refName;
    String content = sha + '\n';
    return FileOps.createFileWithContent(_rootDir, path, content, "Text");
  }

  Future<chrome.FileEntry> setHeadRef(String refName, String sha) {
    String content = 'ref: ${refName}\n';
    return FileOps.createFileWithContent(_rootDir, GIT_HEAD_PATH,
        content, "Text");
  }

  Future<String> getHeadRef() {
    Completer<String> completer = new Completer();
    _rootDir.getFile(GIT_HEAD_PATH).then((chrome.ChromeFileEntry entry) {
      entry.readText().then((String content) {
        // get rid of the initial 'ref: ' plus newline at end
        String headRefName = content.substring(5).trim();
        completer.complete(headRefName);
      });
    }, onError: (e) {
      // throw file error.
    });
    return completer.future;
  }

  Future<String> getHeadSha() {
    return getHeadRef().then((String headRefName)
        => _getHeadForRef(headRefName));
  }

  Future<String> getAllHeads() {
    Completer completer = new Completer();
    _rootDir.getDirectory('.git/refs/heads').then((
        chrome.DirectoryEntry dir) {
      FileOps.listFiles(dir).then((List<chrome.Entry> entries) {
        List<String> branches;
        entries.forEach((chrome.Entry entry) {
          branches.add(entry.name);
        });
        completer.complete(branches);
      });
    }, onError: (e) {
      // TODO(grv): add error codes.
      if (e.code == 'file error') {
        completer.complete([]);
      } else {
        //TODO(grv): throw file error.
      }
    });
    return completer.future;
  }

  Future<String> _getHeadForRef(String headRefName) {
    return FileOps.readFile(_rootDir, GIT_FOLDER_PATH + headRefName, "Text")
      .then((String content) => content.substring(0, 40));
  }

  Future _readPackEntry(chrome.DirectoryEntry packDir,
      chrome.ChromeFileEntry entry) {
    Completer completer = new Completer();
    //TODO(grv) : Read an array buffer instead of text.
    entry.readText().then((String packData) {
      var rootName = entry.name.substring(0, entry.name.lastIndexOf('.pack'));
      FileOps.readFile(packDir, rootName + '.idx', 'ArrayBuffer').then(
          (chrome.ArrayBuffer idxData) {
            //TODO(grv) : Expose the pack and packIndex class, and pass a pack
            // object.
            //this._packs.add({pack: newPacker(packData, this), idx: new PackIndex(idxData)});
            _packs.add("add proper pack class");
            completer.complete();

      }, onError: (e) {
        completer.complete(e);

      });

    }, onError: (e) {
      completer.complete(e);
    });
    return completer.future;
  }
}