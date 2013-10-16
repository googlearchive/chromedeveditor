// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:grinder/grinder.dart';
import 'package:intl/intl.dart';
import 'package:polymer/builder.dart' as polymer;

final NumberFormat _NF = new NumberFormat.decimalPattern();

void main() {
  defineTask('init', taskFunction: init);
  defineTask('sdk', taskFunction: populateSdk, depends: ['init']);
  defineTask('packages', taskFunction: packages, depends: ['init', 'sdk']);

  defineTask('analyze', taskFunction: analyze, depends: ['packages']);
  defineTask('compile', taskFunction: compile, depends: ['packages', 'sdk']);

  defineTask('archive', taskFunction : archive,
             depends : ['compile', 'mode-notest']);
  defineTask('release', taskFunction : release,
             depends : ['compile', 'mode-notest']);

  defineTask('mode-test', taskFunction: (c) => changeMode(c, true));
  defineTask('mode-notest', taskFunction: (c) => changeMode(c, false));

  defineTask('clean', taskFunction: clean);

  startGrinder();
}

bool runCommandSync(GrinderContext context, String command) {
  context.log(command);
  var result = Process.runSync('/bin/sh', ['-c', command]);
  if (result.stdout.isNotEmpty) {
    context.log(result.stdout);
  }
  if (result.stderr.isNotEmpty) {
    context.log(result.stderr);
  }
  return (result.exitCode == 0);
}

String getCommandOutput(String command) {
  var result = Process.runSync('/bin/sh', ['-c', command]);
  return result.stdout.trim();
}

void init(GrinderContext context) {
  // check to make sure we can locate the SDK
  if (sdkDir == null) {
    context.fail("Unable to locate the Dart SDK\n"
        "Please set the DART_SDK environment variable to the SDK path.\n"
        "  e.g.: 'export DART_SDK=your/path/to/dart/dart-sdk'");
  }

  PubTools pub = new PubTools();
  pub.install(context);
}

void clean(GrinderContext context) {
  // delete the sdk directory
  runCommandSync(context, 'rm -rf app/sdk/lib');
  runCommandSync(context, 'rm app/sdk/version');

  // delete any compiled js output
  runCommandSync(context, 'rm app/*.dart.js');
  runCommandSync(context, 'rm app/*.dart.precompiled.js');
  runCommandSync(context, 'rm app/*.js.map');
  runCommandSync(context, 'rm app/*.js.deps');

  // TODO: delete the build/ dir?

}

void packages(GrinderContext context) {
  // copy from ./packages to ./app/packages
  copyDirectory(
      joinDir(Directory.current, ['packages']),
      joinDir(Directory.current, ['app', 'packages']));
}

// Prepare the build folder.
// It will copy all the required source files to build/.
// It will prepare the directory layout to be compatible with polymer builder.
void prepareBuild(GrinderContext context) {
  context.log('prepare build');
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
  runCommandSync(context, 'rm -rf build/web/packages');
}

// It will output a file web/spark.html_bootstrap.dart and a spark.html
// without HTML imports.
Future<bool> asyncPolymerBuild(GrinderContext context,
                               String entryPoint,
                               String outputDir) {
  var args = ['--out', outputDir, '--deploy'];
  var options = polymer.parseOptions(args);
  return polymer.build(entryPoints: [entryPoint], options: options).then((_) {
    context.log("polymer build done");
    return true;
  });
}

// Transpile dart sources to JS.
// It will create spark.html_bootstrap.dart.precompiled.js.
void dart2JSBuild(GrinderContext context) {
  // We remove the symlink and replace it with a copy.
  runCommandSync(context, 'rm -rf web/packages');
  copyDirectory(
      joinDir(Directory.current, ['packages']),
      joinDir(Directory.current, ['web', 'packages']));

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

  printSize(context,  new File('web/spark.html_bootstrap.dart.precompiled.js'));
}

Future compile(GrinderContext context) {
  prepareBuild(context);

  Directory.current = 'build';
  return Future.wait([asyncPolymerBuild(context, 'web/spark.html',
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

// Creates an archive of the Chrome App.
// - Sources will be compiled in Javascript using "compile" task
//
// We'll create an archive using the content of build-chrome-app.
// - Copy the compiled sources to build/chrome-app/spark
// - We clean all packages/ folders that have been duplicated into every
//   folders by the "compile" task
// - Copy the packages/ directory in build/chrome-app/spark/packages
// - Remove test
// - Zip the content of build/chrome-app-spark to dist/spark.zip
//
void archive(GrinderContext context) {
  Directory distDir = new Directory('dist');
  distDir.createSync();

  // Create a build/chrome-app/spark directory to prepare the content of the
  // Chrome App.
  copyDirectory(
      joinDir(Directory.current, ['build', 'polymer-build', 'web']),
      joinDir(Directory.current, ['build', 'chrome-app', 'spark']));
  runCommandSync(
      context,
      'find build/chrome-app/spark -name "packages" -print0 | xargs -0 rm -rf');
  copyDirectory(
      joinDir(Directory.current, ['build', 'polymer-build', 'web', 'packages']),
      joinDir(Directory.current, ['build', 'chrome-app', 'spark', 'packages']));
  runCommandSync(context, 'rm -rf build/chrome-app/spark/test');
  runCommandSync(context, 'rm -rf build/chrome-app/spark/spark_test.dart');

  // zip spark.zip . -r -q -x .*
  Directory.current = 'build/chrome-app/spark';
  runCommandSync(context, 'zip ../../../dist/spark.zip . -qr -x .*');
  Directory.current = '../../..';
  printSize(context, new File('dist/spark.zip'));
}

void printSize(GrinderContext context, File file) {
  int sizeKb = file.lengthSync() ~/ 1024;
  context.log('${file.path} is ${_NF.format(sizeKb)}k');
}

// Returns the name of the current branch.
String getBranchName() {
  return getCommandOutput('git branch | grep "*" | sed -e "s/\* //g"');
}

// Returns the URL of the git repository.
String getRepositoryUrl() {
  return getCommandOutput('git config remote.origin.url');
}

// Returns the current revision identifier of the local copy.
String getCurrentRevision() {
  return getCommandOutput('git rev-parse HEAD | cut -c1-10');
}

// We can build a real release only if the repository is the original
// repository of spark and master is the working branch since we need to
// increase the version and commit it to the repository.
bool canReleaseFromHere() {
  return (getRepositoryUrl() == 'https://github.com/dart-lang/spark.git') &&
         (getBranchName() == 'master');
}

// In case, release is performed on a non-releasable branch/repository, we just
// archive and name the archive with the revision identifier.
void archiveWithRevision(GrinderContext context) {
  context.log('Performing archive instead.');
  archive(context);
  File file = new File('dist/spark.zip');
  String version = getCurrentRevision();
  String filename = 'spark-rev-${version}.zip';
  file.rename('dist/${filename}');
  context.log("Created ${filename}");
}

// Increase the build number in the manifest.json file. Returns the full
// version.
String increaseBuildNumber(GrinderContext context) {
  // Tweaking build version in manifest.
  File file = new File('app/manifest.json');
  String content = file.readAsStringSync();
  var manifestDict = JSON.decode(content);
  String version = manifestDict['version'];
  RegExp exp = new RegExp(r"(\d+\.\d+)\.(\d+)");
  Iterable<Match> matches = exp.allMatches(version);
  assert(matches.length > 0);

  Match m = matches.first;
  String majorVersion = m.group(1);
  int buildVersion = int.parse(m.group(2));
  buildVersion ++;

  version = '${majorVersion}.${buildVersion}';
  manifestDict['version'] = version;
  file.writeAsStringSync(JSON.encode(manifestDict));

  // It needs to be copied to compile result directory.
  copyFile(
      joinFile(Directory.current, ['app', 'manifest.json']),
      joinDir(Directory.current, ['build', 'polymer-build', 'web']));
  return version;
}

// Creates a release build to be uploaded to Chrome Web Store.
// It will perform the following steps:
// - Sources will be compiled in Javascript using "compile" task
// - If the current branch/repo is not releasable, we just create an archive
//   tagged with a revision number.
// - Using increaseBuildNumber, for a given revision number a.b.c where a, b
//   and c are integers, we increase c, the build number and write it to the
//   manifest.json file.
// - We duplicate the manifest.json file to build/polymer-build/web since we'll
//   create the Chrome App from here.
// - "archive" task will create a spark.zip file in dist/, based on the content
//   of build/polymer-build/web.
// - If everything is successful and no exception interrupted the process,
//   we'll commit the new manifest.json containing the updated version number
//   to the repository. The developer still needs to push it to the remote
//   repository.
// - We eventually rename dist/spark.zip to dist/spark-a.b.c.zip to reflect the
//   new version number.
//
void release(GrinderContext context) {
  // If repository is not original repository of Spark and the branch is not
  // master.
  if (!canReleaseFromHere()) {
    archiveWithRevision(context);
    return;
  }

  String version = increaseBuildNumber(context);
  // Creating an archive of the Chrome App.
  context.log('Creating build ${version}');

  archive(context);

  runCommandSync(
    context,
    'git commit -m "Build version ${version}" app/manifest.json');
  File file = new File('dist/spark.zip');
  String filename = 'spark-${version}.zip';
  file.renameSync('dist/${filename}');
  context.log('Created ${filename}');
  context.log('** A commit has been created, you need to push it. ***');
}

/**
 * Populate the 'app/sdk' directory from the current Dart SDK.
 */
void populateSdk(GrinderContext context) {
  Directory srcSdkDir = sdkDir;
  Directory destSdkDir = new Directory('app/sdk');

  destSdkDir.createSync();

  File srcVersionFile = joinFile(srcSdkDir, ['version']);
  File destVersionFile = joinFile(destSdkDir, ['version']);

  FileSet srcVer = new FileSet.fromFile(srcVersionFile);
  FileSet destVer = new FileSet.fromFile(destVersionFile);

  Directory compilerDir = new Directory('packages/compiler');

  // check the state of the sdk/version file, to see if things are up-to-date
  if (!destVer.upToDate(srcVer) || !compilerDir.existsSync()) {
    // copy files over
    context.log('copying SDK');
    copyFile(srcVersionFile, destSdkDir);
    copyDirectory(joinDir(srcSdkDir, ['lib']), joinDir(destSdkDir, ['lib']));

    // Create a synthetic package:compiler package in the packages directory.
    compilerDir.createSync();

    runCommandSync(context, 'rm -rf packages/compiler/compiler');
    runCommandSync(context, 'rm -rf packages/compiler/lib');
    runCommandSync(context, 'rm -rf app/sdk/lib/_internal/compiler/samples');
    runCommandSync(context, 'mv app/sdk/lib/_internal/compiler packages/compiler');
    runCommandSync(context, 'mv app/sdk/lib/_internal/lib packages/compiler');
    runCommandSync(context, 'cp app/sdk/lib/_internal/libraries.dart packages/compiler');
    runCommandSync(context, 'rm -rf app/sdk/lib/_internal/pub');
    runCommandSync(context, 'rm -rf app/sdk/lib/_internal/dartdoc');

    // traverse directories, creating a .files json directory listing
    context.log('creating SDK directory listings');
    createDirectoryListings(destSdkDir);
  }
}

/**
 * Recursively create `.files` json files in the given directory; these files
 * serve as directory listings.
 */
void createDirectoryListings(Directory dir) {
  List<String> files = [];

  String parentName = fileName(dir);

  for (FileSystemEntity entity in dir.listSync(followLinks: false)) {
    String name = fileName(entity);

    // ignore hidden files and directories
    if (name.startsWith('.')) continue;

    if (entity is File) {
      files.add(name);
    } else {
      files.add("${name}/");
      createDirectoryListings(entity);
    }
  };

  joinFile(dir, ['.files']).writeAsStringSync(JSON.encode(files));
}
