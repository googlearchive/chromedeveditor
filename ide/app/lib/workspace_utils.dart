// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.workspace_utils;

import 'dart:async';
import 'dart:convert';

import 'package:archive/archive.dart' as archive;

import 'workspace.dart';

Future archiveContainer(Container container, [bool addZipManifest = false]) {
  archive.Archive arch = new archive.Archive();
  return _recursiveArchive(arch, container, addZipManifest ? 'www/' : '').then((_) {
    if (addZipManifest) {
      String zipAssetManifestString = _buildZipAssetManifest(container);
      arch.addFile(new archive.ArchiveFile('zipassetmanifest.json',
          zipAssetManifestString.codeUnits.length,
          zipAssetManifestString.codeUnits));
    }
    return new archive.ZipEncoder().encode(arch);
  });
}

/**
 * Return (or create) the child file of the given folder.
 */
Future<File> getCreateFile(Folder parent, String filename) {
  File file = parent.getChild(filename);

  if (file == null) {
    return parent.createNewFile(filename);
  } else {
    return new Future.value(file);
  }
}

/**
 * Given a file and a relative path from it, resolve the target file. Can return
 * `null`.
 */
Resource resolvePath(File file, String path) {
  return _resolvePaths(file.parent, path.split('/'));
}

Resource _resolvePaths(Container container, Iterable<String> pathElements) {
  if (pathElements.isEmpty || container == null) return null;

  String element = pathElements.first;

  if (pathElements.length == 1) {
    return container.getChild(element);
  }

  if (element == '..') {
    return _resolvePaths(container.parent, pathElements.skip(1));
  } else {
    return _resolvePaths(container.getChild(element), pathElements.skip(1));
  }
}

String _buildZipAssetManifest(Container container) {
  Iterable<Resource> children = container.traverse().skip(1);
  int rootIndex = container.path.length + 1;
  Map<String, Map<String, String>> zipAssetManifest = {};
  for (Resource element in children) {
    if (element.isFile) {
      String path = element.path.substring(rootIndex);
      zipAssetManifest["www/$path"] = {"path": "www/$path", "etag": "0"};
    }
  }

  return JSON.encode(zipAssetManifest);
}

Future _recursiveArchive(archive.Archive arch, Container parent,
    [String prefix = '']) {
  List<Future> futures = [];

  for (Resource child in parent.getChildren()) {
    if (child is File) {
      futures.add(child.getBytes().then((buf) {
        List<int> data = buf.getBytes();
        arch.addFile(new archive.ArchiveFile('${prefix}${child.name}',
            data.length, data));
      }));
    } else if (child is Folder) {
      futures.add(_recursiveArchive(arch, child, '${prefix}${child.name}/'));
    }
  }

  return Future.wait(futures);
}
