// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.workspace_utils;

import 'dart:async';
import 'dart:convert';

import 'package:archive/archive.dart' as archive;

import 'workspace.dart';

Future archiveContainer(Container container, [bool addManifest = false]) {
  archive.Archive arch = new archive.Archive();
  return _recursiveArchive(arch, container, 'www/').then((_) {
    if (addManifest) {
      String zipAssetManifestString = _buildZipAssetManifest(container);
      /*%TRACE3*/ print("""(4> 6/8/14): zipAssetManifestString: ${zipAssetManifestString}"""); // TRACE%
      arch.addFile(new archive.ArchiveFile('zipassetmanifest.json',
          zipAssetManifestString.codeUnits.length,
          zipAssetManifestString.codeUnits));
    }
    return new archive.ZipEncoder().encode(arch);
  });
}

String _buildZipAssetManifest(Container container) {
  Iterable<Resource> children = container.traverse().skip(1);
  int rootIndex = container.path.length + 1;
  Map<String, Map<String, String>> zipassetManifest = {};
  for (Resource element in children) {
    /*%TRACE3*/ print("""(4> 6/8/14): element.path: ${element.path}"""); // TRACE%
    String path = element.path.substring(rootIndex);
    zipassetManifest["www/$path"] = {"path": "www/$path", "etag": 0};
  }

  return JSON.encode(zipassetManifest);
}

Future _recursiveArchive(archive.Archive arch, Container parent,
      [String prefix = '']) {
  List<Future> futures = [];

  for (Resource child in parent.getChildren()) {
    if (child is File) {
      futures.add(child.getBytes().then((buf) {
        List<int> data = buf.getBytes();
        /*%TRACE3*/ print("""(4> 6/9/14): '${prefix}${child.name}': ${'${prefix}${child.name}'}"""); // TRACE%
        arch.addFile(new archive.ArchiveFile('${prefix}${child.name}',
            data.length, data));
      }));
    } else if (child is Folder) {
      futures.add(_recursiveArchive(arch, child, '${prefix}${child.name}/'));
    }
  }

  return Future.wait(futures);
}
