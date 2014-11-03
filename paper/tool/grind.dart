// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:io';

import 'package:grinder/grinder.dart';
import 'package:path/path.dart' as path;

final Directory LIB_DIR = new Directory('lib');

void main([List<String> args]) {
  task('init', init);
  task('update', update, ['init']);
  task('deleteDemos', deleteDemos, ['init']);
  task('vulcanize', vulcanize, ['deleteDemos']);
  task('clean', clean);

  startGrinder(args);
}

/**
 * Do any necessary build set up.
 */
void init(GrinderContext context) {
  // Verify we're running in the project root.
  if (!getDir('lib').existsSync() || !getFile('pubspec.yaml').existsSync()) {
    context.fail('This script must be run from the project root.');
  }
}

/**
 * Run `bower update`.
 */
void update(GrinderContext context) {
  runProcess(context, 'bower', arguments: ['update']);
}

/**
 * Remove un-needed demo and sample content.
 */
void deleteDemos(GrinderContext context) {
  const List delNames = const [
      '.bower.json', 'bower.json', 'demo.html', 'index.html', 'metadata.html'
   ];

  Iterable directories = _directoriesInLib;

  var fn = (dir) {
    if (dir is! Directory) return false;
    String name = path.basename(dir.path);
    return name == 'demos' || name == 'test' || name == 'tests';
  };

  Iterable toDelete = directories.expand((d) => d.listSync().where(fn));
  toDelete.forEach((FileSystemEntity entity) => deleteEntity(entity, context));

  // Delete un-needed .md, index.html, and demo.html files
  List entities = LIB_DIR.listSync(recursive: true, followLinks: false);

  for (FileSystemEntity entity in entities) {
    if (entity is File) {
      String name = path.basename(entity.path);

      if (delNames.contains(name) || name.endsWith('.md')) {
        deleteEntity(entity, context);
      }
    }
  }
}

/**
 * TODO: doc
 */
void vulcanize(GrinderContext context) {
  Iterable directories = _directoriesInLib;
  Iterable files = directories.expand(_listFiles);

  //files.forEach((file) => _normalizeReferences(file));

  files = files.where(_isNotDemo);
  files = files.where(_hasScript);

  files.forEach((file) => _vulcanize(context, file));
}

void clean(GrinderContext context) {

}

void _vulcanize(GrinderContext context, File file) {
  final String START = '<script>';
  final String END = '</script>';

  String filePath = file.path;
  context.log('vulcanizing ${filePath}');

  String content = file.readAsStringSync();
  int count = 0;

  while (content.contains(START)) {
    int start = content.indexOf(START);
    int end = content.indexOf(END, start);

    if (end == -1) break;

    String script = content.substring(start, end);
    script = script.substring(START.length);

    File outFile = new File(filePath.substring(0, filePath.length - 5)
        + (count == 0 ? '' : '-${count}')
        + '.js');
    String fileName = path.basename(outFile.path);
    outFile.writeAsStringSync(script);

    content = content.substring(0, start)
        + '<script src="${fileName}"></script>'
        + content.substring(end + END.length);

    count++;
  }

  if (count > 0) {
    file.writeAsStringSync(content);
  }
}

void _normalizeReferences(File file) {
  // href="../polymer/polymer.html"
  // href="../../packages/polymer/polymer.html"

  // src="../platform/platform.js"
  // src="../../packages/platform/platform.js"

  String contents = file.readAsStringSync();

  contents = contents.replaceAll(
      'href="../polymer/polymer.html"',
      'href="../../polymer/polymer.html"');

  contents = contents.replaceAll(
      'src="../platform/platform.js"',
      'src="../../platform/platform.js"');

  file.writeAsStringSync(contents);
}

Iterable _listFiles(Directory dir) {
  return dir.listSync(recursive: true, followLinks: false)
    .where((e) => e is File)
    .where((f) => f.path.endsWith('.html'));
}

bool _isNotDemo(File file) {
  String name = path.basename(file.path);
  if (name == 'demo.html') return false;
  if (name == 'index.html') return false;
  if (name == 'metadata.html') return false;
  return true;
}

bool _hasScript(File file) {
  String str = file.readAsStringSync().toLowerCase();
  return str.contains('<script>');
}

Iterable get _directoriesInLib => LIB_DIR.listSync().where((dir) {
  String name = path.basename(dir.path);
  return name.startsWith('core-') || name.startsWith('paper-')
      || name.startsWith('context-');
});
