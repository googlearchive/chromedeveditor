// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:grinder/grinder.dart';
import 'package:polymer/builder.dart' as polymer;

void main() {
  defineTask('init', taskFunction: init);
  defineTask('packages', taskFunction: packages, depends: ['init']);
  defineTask('analyze', taskFunction: analyze, depends: ['packages']);
  defineTask('sdk', taskFunction: populateSdk);
  defineTask('compile', taskFunction: compile, depends: ['packages', 'sdk']);
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
  // Change the name of the folder to web because polymer builder will only
  // build content from 'web' folder.
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
  var options = polymer.parseOptions(args);
  return polymer.build(entryPoints: [entryPoint], options: options)
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
    Directory.current = '../..';
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

/**
 * Populate an 'app/sdk' directory from the current Dart SDK.
 */
void populateSdk(GrinderContext context) {
  Directory srcSdkDir = sdkDir;
  Directory destSdkDir = new Directory('app/sdk');

  destSdkDir.createSync();

  File srcVersionFile = joinFile(srcSdkDir, ['version']);
  File destVersionFile = joinFile(destSdkDir, ['version']);

  FileSet srcVer = new FileSet.fromFile(srcVersionFile);
  FileSet destVer = new FileSet.fromFile(destVersionFile);

  // check the state of the sdk/version file, to see if things are up-to-date
  if (!destVer.upToDate(srcVer)) {
    // copy files over
    context.log('copying SDK');
    copyFile(srcVersionFile, destSdkDir);
    copyDirectory(joinDir(srcSdkDir, ['lib']), joinDir(destSdkDir, ['lib']));

    // traverse directories, creating a .files json directory listing
    context.log('creating SDK directory listings');
    createDirectoryListings(destSdkDir);
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

void createDirectoryListings(Directory dir) {
  List<String> files = [];

  dir.listSync(followLinks: false).forEach((FileSystemEntity entity) {
    String name = fileName(entity);

    if (!name.startsWith('.')) {
      if (entity is File) {
        files.add(name);
      } else {
        files.add("${name}/");
        createDirectoryListings(entity);
      }
    }
  });

  File jsonFile = joinFile(dir, ['.files']);
  jsonFile.writeAsStringSync(JSON.encode(files));
}
