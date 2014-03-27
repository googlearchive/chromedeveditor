// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library spark.project_builder;

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:html' hide File;

import 'package:chrome/chrome_app.dart' as chrome;

import 'utils.dart';

/**
 * A class to create a sample project given a project name and the template id
 * to use.
 */
class ProjectBuilder {
  DirectoryEntry _destRoot;
  String _sourceName;
  String _projectName;
  String _sourceUri;

  ProjectBuilder(this._destRoot, String templateId, this._sourceName,
      this._projectName) {
    _sourceUri = 'resources/templates/$templateId';
  }

  /**
   * Build the sample project and complete the Future when finished.
   */
  Future build() {
    DirectoryEntry sourceRoot;

    return getPackageDirectoryEntry().then((root) {
      return root.getDirectory(_sourceUri);
    }).then((dir) {
      sourceRoot = dir;
      return getAppContents("$_sourceUri/setup.json");
    }).then((String contents) {
      Map m = JSON.decode(contents);
      return traverseElement(_destRoot, sourceRoot, _sourceUri, m);
    });
  }

  Future traverseElement(DirectoryEntry destRoot, DirectoryEntry sourceRoot,
      String sourceUri, Map element) {
    return handleDirectories(destRoot, sourceRoot, sourceUri,
        element['directories']).then((_) =>
            handleFiles(destRoot, sourceRoot, sourceUri, element['files']));
  }

  Future handleDirectories(DirectoryEntry destRoot, DirectoryEntry sourceRoot,
      String sourceUri, Map directories) {
    if (directories != null) {
      return Future.forEach(directories.keys, (String directoryName) {
        DirectoryEntry destDirectoryRoot;
        return _destRoot.createDirectory(directoryName).then((DirectoryEntry entry) {
          destDirectoryRoot = entry;
          return sourceRoot.getDirectory(directoryName);
        }).then((DirectoryEntry sourceDirectoryRoot) {
          return traverseElement(destDirectoryRoot, sourceDirectoryRoot,
              "$sourceUri/$directoryName", directories[directoryName]);
        });
      });
    }

    return new Future.value();
  }

  Future handleFiles(DirectoryEntry destRoot, DirectoryEntry sourceRoot,
      String sourceUri, List files) {
    if (files == null) return new Future.value();

    return Future.forEach(files, (fileElement) {
      String source = fileElement['source'];
      String dest = fileElement['dest'];

      dest = dest
          .replaceAll("\$sourceName", _sourceName)
          .replaceAll("\$projectName", _projectName);

      chrome.ChromeFileEntry entry;

      return destRoot.createFile(dest).then((chrome.ChromeFileEntry _entry) {
        entry = _entry;
        if (dest.endsWith(".png")) {
          return getAppContentsBinary("$sourceUri/$source").then((List<int> data) {
            return entry.writeBytes(new chrome.ArrayBuffer.fromBytes(data));
          });
        } else {
          return getAppContents("$sourceUri/$source").then((String data) {
            data = data
                .replaceAll("_Project_name_", _projectName)
                .replaceAll("_source_name_", _sourceName);
            return entry.writeText(data);
          });
        }
      });
    });
  }
}
