// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:io';

import 'package:grinder/grinder.dart';
import 'package:polymer/builder.dart' as cb;
import 'dart:async';

void main() {
  defineTask('init', taskFunction: init);
  defineTask('packages', taskFunction: packages, depends: ['init']);
  defineTask('analyze', taskFunction: analyze, depends: ['packages']);
  defineTask('compile', taskFunction: compile, depends: ['packages']);
  defineTask('archive', taskFunction: archive, depends: ['compile', 'mode-notest']);

  defineTask('mode-test', taskFunction: (c) => changeMode(c, true));
  defineTask('mode-notest', taskFunction: (c) => changeMode(c, false));

  startGrinder();
}

void init(GrinderContext context) {
  PubTools pub = new PubTools();
  pub.install(context);
}

void packages(GrinderContext context) {
  // copy from ./packages to ./app/packages
  copyDirectory(
      joinDir(Directory.current, ['packages']),
      joinDir(Directory.current, ['app', 'packages']));

  // Copy files to build directory.
  copyFile(
      joinFile(Directory.current, ['pubspec.yaml']),
      joinDir(Directory.current, ['build']));
  copyFile(
      joinFile(Directory.current, ['pubspec.lock']),
      joinDir(Directory.current, ['build']));
  copyDirectory(
      joinDir(Directory.current, ['app']),
      joinDir(Directory.current, ['build', 'web']));
  copyDirectory(
      joinDir(Directory.current, ['packages']),
      joinDir(Directory.current, ['build', 'packages']));
  Process.runSync('rm', ['-rf', 'build/web/packages']);
}

// It will output a file web/spark.html_bootstrap.dart and a spark.html
// without HTML imports.
Future<bool> asyncPolymerBuild(String entryPoint, String outputDir) {
  var args = ['--out', outputDir, '--deploy'];
  var options = cb.parseOptions(args);
  return cb.build(entryPoints: [entryPoint], options: options)
      .then((_) => true);
  print("polymer build done");
}

void dart2JSBuild(GrinderContext context) {
  // We remove the symlink and replace it with a copy.
  Process.runSync('rm', ['-rf', 'web/packages']);
  copyDirectory(
      joinDir(Directory.current, ['packages']),
      joinDir(Directory.current, ['web', 'packages']));

  // TODO: check outputs
  // We tell dart2js to compile to spark.dart.js; it also outputs a CSP
  // version (spark.dart.precompiled.js), which is what we actually use.
  runProcess(context, 'dart2js', arguments: [
      'web/spark.html_bootstrap.dart',
      '--out=web/spark.html_bootstrap.dart.js']);

  // Support for old version of dart2js: they generate precompiled.js file.
  if (new File('web/precompiled.js').existsSync()) {
    new File('web/precompiled.js').renameSync(
        'web/spark.html_bootstrap.dart.precompiled.js');
  }
  int sizeKb = new File('web/spark.html_bootstrap.dart.precompiled.js').lengthSync() ~/ 1024;
  context.log('spark.html_bootstrap.dart.precompiled.js is ${sizeKb}kb');
}

Future compile(GrinderContext context) {
  Directory.current = 'build';
  return Future.wait([asyncPolymerBuild('web/spark.html',
                                        'polymer-build').then((bool success) {
    Directory.current = 'polymer-build';
    dart2JSBuild(context);
    context.log('result has been written to build/polymer-build/web/');
  })]);
}

void analyze(GrinderContext context) {
  runProcess(context, 'dartanalyzer', arguments: ['app/spark.dart']);
  runProcess(context, 'dartanalyzer', arguments: ['app/spark_test.dart']);
}

void changeMode(GrinderContext context, bool useTestMode) {
  final testMode = 'src="spark_test.dart';
  final noTestMode = 'src="spark.dart';

  File htmlFile = joinFile(Directory.current, ['app', 'spark.html']);

  String contents = htmlFile.readAsStringSync();

  if (useTestMode) {
    if (contents.contains(noTestMode)) {
      contents = contents.replaceAll(noTestMode, testMode);
      htmlFile.writeAsStringSync(contents);
    }
  } else {
    if (contents.contains(testMode)) {
      contents = contents.replaceAll(testMode, noTestMode);
      htmlFile.writeAsStringSync(contents);
    }
  }
}

void archive(GrinderContext context) {
  Directory distDir = new Directory('dist');
  distDir.createSync();

  // zip spark.zip . -r -q -x .*
  runProcess(context,
      'zip', arguments: ['../dist/spark.zip', '.', '-r', '-q', '-x', '.*'],
      workingDirectory: 'app');
  int sizeKb = new File('dist/spark.zip').lengthSync() ~/ 1024;
  context.log('spark.zip is ${sizeKb}kb');
}
