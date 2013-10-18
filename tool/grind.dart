// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:grinder/grinder.dart';
import 'package:intl/intl.dart';

final NumberFormat _NF = new NumberFormat.decimalPattern();

// TODO: release task

void main() {
  defineTask('setup', taskFunction: setup);

  defineTask('mode-test', taskFunction: (c) => _changeMode(c, true));
  defineTask('mode-notest', taskFunction: (c) => _changeMode(c, false));

  defineTask('deploy-test', taskFunction: deployTest, depends : ['setup', 'mode-test']);
  defineTask('deploy-notest', taskFunction: deployNoTest, depends : ['setup', 'mode-notest']);

  defineTask('release', taskFunction : release, depends : ['deploy-notest']);
  defineTask('archive', taskFunction : archive, depends : ['deploy-notest']);

  defineTask('clean', taskFunction: clean);

  startGrinder();
}

/**
 * Init needed dependencies.
 */
void setup(GrinderContext context) {
  // check to make sure we can locate the SDK
  if (sdkDir == null) {
    context.fail("Unable to locate the Dart SDK\n"
        "Please set the DART_SDK environment variable to the SDK path.\n"
        "  e.g.: 'export DART_SDK=your/path/to/dart/dart-sdk'");
  }

  PubTools pub = new PubTools();
  pub.install(context);

  _populateSdk(context);

  // copy from ./packages to ./app/packages
  copyDirectory(
      joinDir(Directory.current, ['packages']),
      joinDir(Directory.current, ['app', 'packages']));
}

/**
 * TODO:
 */
void deployTest(GrinderContext context) {
  Directory target = new Directory('build/deploy-test');
  _polymerDeploy(context, target);
  _dart2jsCompile(target, 'spark_test.dart');
}

/**
 * TODO:
 */
void deployNoTest(GrinderContext context) {
  Directory target = new Directory('build/deploy-notest');
  _polymerDeploy(context, target);
  _dart2jsCompile(target, 'spark.dart');
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

  _runCommandSync(
    context,
    'git commit -m "Build version ${version}" app/manifest.json');
  File file = new File('dist/spark.zip');
  String filename = 'spark-${version}.zip';
  file.renameSync('dist/${filename}');
  context.log('Created ${filename}');
  context.log('** A commit has been created, you need to push it. ***');
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
void archive(GrinderContext context) {
  Directory distDir = new Directory('dist');
  distDir.createSync();

  // Create a build/chrome-app/spark directory to prepare the content of the
  // Chrome App.
  copyDirectory(
      joinDir(Directory.current, ['build', 'polymer-build', 'web']),
      joinDir(Directory.current, ['build', 'chrome-app', 'spark']));
  _runCommandSync(
      context,
      'find build/chrome-app/spark -name "packages" -print0 | xargs -0 rm -rf');
  copyDirectory(
      joinDir(Directory.current, ['build', 'polymer-build', 'web', 'packages']),
      joinDir(Directory.current, ['build', 'chrome-app', 'spark', 'packages']));
  _runCommandSync(context, 'rm -rf build/chrome-app/spark/test');
  _runCommandSync(context, 'rm -rf build/chrome-app/spark/spark_test.dart');

  // zip spark.zip . -r -q -x .*
  _runCommandSync(context, 'zip ../../../dist/spark.zip . -qr -x .*',
      cwd: 'build/chrome-app/spark');
  _printSize(context, new File('dist/spark.zip'));
}

/**
 * TODO:
 */
void clean(GrinderContext context) {
  // delete the sdk directory
  _runCommandSync(context, 'rm -rf app/sdk/lib');
  _runCommandSync(context, 'rm -f app/sdk/version');

  // delete any compiled js output
  _runCommandSync(context, 'rm -f app/*.dart.js');
  _runCommandSync(context, 'rm -f app/*.dart.precompiled.js');
  _runCommandSync(context, 'rm -f app/*.js.map');
  _runCommandSync(context, 'rm -f app/*.js.deps');

  // delete the build/ dir
  _runCommandSync(context, 'rm -rf build');
}

void _polymerDeploy(GrinderContext context, Directory target) {
  _runCommandSync(context, 'rm -rf ${target}');
  target.createSync();

  // copy the app directory to target/web

  Directory saveDir = Directory.current;
  Directory.current = cwd;
  // TODO: allow runDartScript() to specify the cwd
  runDartScript(context, 'packages/polymer/deploy.dart',
                arguments: ['--out', outputDir],
                packageRoot: 'packages');
  Directory.current = saveDir;


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
  _runCommandSync(context, 'rm -rf build/web/packages');
}

// It will output a file web/spark.html_bootstrap.dart and a spark.html
// without HTML imports.
void runPolymerBuild(GrinderContext context,
                     String entryPoint,
                     String outputDir,
                     Directory cwd) {
  Directory saveDir = Directory.current;
  Directory.current = cwd;
  // TODO: allow runDartScript() to specify the cwd
  runDartScript(context, 'packages/polymer/deploy.dart',
                arguments: ['--out', outputDir],
                packageRoot: 'packages');
  Directory.current = saveDir;
}

// Transpile dart sources to JS.
// It will create spark.html_bootstrap.dart.precompiled.js.
void dart2JSBuild(GrinderContext context, Directory buildDir) {
  // We remove the symlink and replace it with a copy.
  _runCommandSync(context, 'rm -rf web/packages');
  copyDirectory(
      joinDir(Directory.current, ['packages']),
      joinDir(Directory.current, ['web', 'packages']));

  Directory webDir = joinDir(buildDir, ['web']);

  // We tell dart2js to compile to spark.dart.js; it also outputs a CSP
  // version (spark.dart.precompiled.js), which is what we actually use.
  runSdkBinary(context, 'dart2js', arguments: [
      joinDir(webDir, ['spark.html_bootstrap.dart']).path,
      '--out=' + joinDir(webDir, ['spark.html_bootstrap.dart.js']).path]);

  // clean up unnecessary (and large) files
  _runCommandSync(context, 'rm -rf ${joinFile(webDir, ['spark.html_bootstrap.dart.js'])}');
  _runCommandSync(context, 'rm -rf ${joinFile(webDir, ['spark.html_bootstrap.dart.js.deps'])}');
  _runCommandSync(context, 'rm -rf ${joinFile(webDir, ['spark.html_bootstrap.dart.js.map'])}');

  _printSize(context,  joinFile(webDir, ['spark.html_bootstrap.dart.precompiled.js']));
}

void compile(GrinderContext context) {
  prepareBuild(context);
  runPolymerBuild(context, 'web/spark.html',
      'polymer-build', new Directory('build'));
  dart2JSBuild(context, new Directory('build/polymer-build'));
  context.log('result has been written to build/polymer-build/web/');
}

void _changeMode(GrinderContext context, bool useTestMode) {
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

// Returns the name of the current branch.
String getBranchName() {
  return _getCommandOutput('git branch | grep "*" | sed -e "s/\* //g"');
}

// Returns the URL of the git repository.
String getRepositoryUrl() {
  return _getCommandOutput('git config remote.origin.url');
}

// Returns the current revision identifier of the local copy.
String getCurrentRevision() {
  return _getCommandOutput('git rev-parse HEAD | cut -c1-10');
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

/**
 * Populate the 'app/sdk' directory from the current Dart SDK.
 */
void _populateSdk(GrinderContext context) {
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

    // lib/_internal/compiler, dartdoc, and pub are not sdk libraries, but do
    // take up a lot of space; remove them
    _runCommandSync(context, 'rm -rf app/sdk/lib/_internal/compiler');
    _runCommandSync(context, 'rm -rf app/sdk/lib/_internal/dartdoc');
    _runCommandSync(context, 'rm -rf app/sdk/lib/_internal/pub');

    // traverse directories, creating a .files json directory listing
    context.log('creating SDK directory listings');
    _createDirectoryListings(destSdkDir);
  }
}

/**
 * Recursively create `.files` json files in the given directory; these files
 * serve as directory listings.
 */
void _createDirectoryListings(Directory dir) {
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
      _createDirectoryListings(entity);
    }
  };

  joinFile(dir, ['.files']).writeAsStringSync(JSON.encode(files));
}

void _printSize(GrinderContext context, File file) {
  int sizeKb = file.lengthSync() ~/ 1024;
  context.log('${file.path} is ${_NF.format(sizeKb)}k');
}

void _runCommandSync(GrinderContext context, String command, {String cwd}) {
  context.log(command);

  var result = Process.runSync(
      '/bin/sh', ['-c', command], workingDirectory: cwd);

  if (result.stdout.isNotEmpty) {
    context.log(result.stdout);
  }
  if (result.stderr.isNotEmpty) {
    context.log(result.stderr);
  }

  if (result.exitCode > 0) {
    context.fail("exit code ${result.exitCode}");
  }
}

String _getCommandOutput(String command) {
  return Process.runSync('/bin/sh', ['-c', command]).stdout.trim();
}
