// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of spark.templates;

class StagehandProjectTemplate implements ProjectTemplate {
  final String id;

  StagehandProjectTemplate(this.id, List<TemplateVar> globalVars,
      List<TemplateVar> localVars);

  Future instantiate(DirectoryEntry destination) {
    stagehand.Generator generator = stagehand.getGenerator(id);
    var target = new _StagehandGeneratorTarget(destination);
    return generator.generate(_normalizeName(destination.name), target,
        additionalVars: {});
  }

  Future showIntro(Project finalProject, utils.Notifier notifier) {
    return new Future.value();
  }

  String _normalizeName(String name) => name.replaceAll('-', '_');
}

class _StagehandGeneratorTarget implements stagehand.GeneratorTarget {
  final DirectoryEntry root;

  _StagehandGeneratorTarget(this.root);

  Future createFile(String path, List<int> contents) {
    List<String> segments = path.split('/');
    return _createFile(root, segments.take(segments.length - 1),
        segments.last, contents);
  }

  Future _createFile(DirectoryEntry dir, Iterable<String> dirs, String fileName,
      List<int> contents) {
    if (dirs.isNotEmpty) {
      return dir.createDirectory(dirs.first).then((DirectoryEntry newDir) {
        return _createFile(newDir, dirs.skip(1), fileName, contents);
      });
    } else {
      return dir.createFile(fileName).then((entry) {
        if (entry is chrome.ChromeFileEntry) {
          return entry.writeBytes(new chrome.ArrayBuffer.fromBytes(contents));
        } else {
          return new Future.error('todo');
        }
      });
    }
  }
}
