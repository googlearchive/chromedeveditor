// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:io';

import 'package:grinder/grinder.dart';
import 'package:path/path.dart' as path;

final Directory LIB_DIR = new Directory('lib');

void main([List<String> args]) {
  defineTask('init', taskFunction: init);
  defineTask('vulcanize', taskFunction: vulcanize, depends: ['init']);
  //defineTask('process', taskFunction: process, depends: ['init']);
  defineTask('clean', taskFunction: clean);

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

void process(GrinderContext context) {
  // TODO:
  // href="../polymer/polymer.html"

//  deleteEntity(joinDir(LIB_DIR, ['platform']));
//  deleteEntity(joinDir(LIB_DIR, ['polymer']));

}

/**
 * TODO:
 */
void vulcanize(GrinderContext context) {
  Iterable directories = LIB_DIR.listSync().where((dir) {
    String name = path.basename(dir.path);
    return name.startsWith('core-') || name.startsWith('paper-');
  });

  Iterable files = directories.expand(_listFiles);

  files.forEach((file) => _normalizeReferences(file));

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
  return dir.listSync()
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
