// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.workspace_utils;

import 'dart:async';

import 'package:archive/archive.dart' as archive;

import 'workspace.dart';

Future archiveContainer(Container container) {
  archive.Archive arch = new archive.Archive();
  return _recursiveArchive(arch, container).then((_) {
    return new archive.ZipEncoder().encode(arch);
  });
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
