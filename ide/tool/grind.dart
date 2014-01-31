// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:grinder/grinder.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:polymer/builder.dart' as polymer;

import 'webstore_client.dart';

final NumberFormat _NF = new NumberFormat.decimalPattern();

// TODO: Make the deploy-test and deploy tasks incremental.

final Directory BUILD_DIR = new Directory('build');
final Directory DIST_DIR = new Directory('dist');

// Here's how to generate refreshToken:
// https://docs.google.com/a/google.com/document/d/1OEM4GGhMrOWS4pYvtIWtkw_17C2pAlWPxUFu-7_YF-4
final String clientID = Platform.environment['SPARK_UPLOADER_CLIENTID'];
final String clientSecret =
    Platform.environment['SPARK_UPLOADER_CLIENTSECRET'];
final String refreshToken =
    Platform.environment['SPARK_UPLOADER_REFRESHTOKEN'];
final String appID = Platform.environment['SPARK_APP_ID'];

void main([List<String> args]) {
  defineTask('setup', taskFunction: setup);

  defineTask('mode-notest', taskFunction: (c) => _changeMode(useTestMode: false));
  defineTask('mode-test', taskFunction: (c) => _changeMode(useTestMode: true));

  defineTask('lint', taskFunction: lint, depends: ['setup']);

  defineTask('compile', taskFunction: compile, depends : ['setup']);
  defineTask('deploy', taskFunction: deploy, depends : ['lint']);

  defineTask('docs', taskFunction: docs, depends : ['setup']);
  defineTask('stats', taskFunction: stats);
  defineTask('archive', taskFunction: archive, depends : ['mode-notest', 'deploy']);
  defineTask('createSdk', taskFunction: createSdk);

  // For now, we won't be building the webstore version from Windows.
  if (!Platform.isWindows) {
    defineTask('release', taskFunction: release, depends : ['mode-notest', 'deploy']);
    defineTask('release-nightly',
               taskFunction : releaseNightly,
               depends : ['mode-notest', 'deploy']);
  }

  defineTask('clean', taskFunction: clean);

  startGrinder(args);
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
  pub.get(context);

  // copy from ./packages to ./app/packages
  copyDirectory(getDir('packages'), getDir('app/packages'), context);

  BUILD_DIR.createSync();
  DIST_DIR.createSync();
}

/**
 * Runt Polymer lint on the Polymer entry point.
 */
void lint(context) {
  polymer.lint(entryPoints: ['app/spark_polymer.html']);
}

/**
 * Compile the Spark non-Polymer entry-point. This step will be removed soon in
 * favor of the Polymer-oriented [deploy].
 */
@deprecated
void compile(GrinderContext context) {
  _dart2jsCompile(context, new Directory('app'), 'spark.dart');
}

/**
 * Copy all source to `build/deploy`. Do a polymer deploy to `build/deploy-out`.
 * This builds the regular (non-test) version of the app.
 */
void deploy(GrinderContext context) {
  Directory sourceDir = joinDir(BUILD_DIR, ['deploy']);
  Directory destDir = joinDir(BUILD_DIR, ['deploy-out']);

  _polymerDeploy(context, sourceDir, destDir);

  _dart2jsCompile(
      context, joinDir(destDir, ['web']),
      'spark_polymer.html_bootstrap.dart', true);
  _runCommandSync(
      context,
      'patch ${destDir.path}/web/packages/shadow_dom/shadow_dom.debug.js tool/shadow_dom.patch');
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
  if (!_canReleaseFromHere()) {
    _archiveWithRevision(context);
    return;
  }

  String version = _increaseBuildNumber(context, removeKey: true);
  // Creating an archive of the Chrome App.
  context.log('Creating build ${version}');

  String filename = 'spark-${version}.zip';
  archive(context, filename);

  var sep = Platform.pathSeparator;
  _runCommandSync(
    context,
    'git checkout app${sep}manifest.json');
  _increaseBuildNumber(context);
  _runCommandSync(
    context,
    'git commit -m "Build version ${version}" app${sep}manifest.json');

  context.log('Created ${filename}');
  context.log('** A commit has been created, you need to push it. ***');
  print('Do you want to push to the remote git repository now? (y/n [n])');
  var line = stdin.readLineSync();
  if (line.trim() == 'y') {
    _runCommandSync(context, 'git push origin master');
  }
}

Future releaseNightly(GrinderContext context) {
  if (clientID == null) {
    context.fail("SPARK_UPLOADER_CLIENTID environment variable should be set and contain the client ID.");
  }
  if (clientSecret == null) {
    context.fail("SPARK_UPLOADER_CLIENTSECRET environment variable should be set and contain the client secret.");
  }
  if (refreshToken == null) {
    context.fail("SPARK_UPLOADER_REFRESHTOKEN environment variable should be set and contain the refresh token.");
  }
  if (appID == null) {
    context.fail("SPARK_APP_ID environment variable should be set and contain the refresh token.");
  }

  String version =
      _modifyManifestWithDroneIOBuildNumber(context, removeKey: true);

  // Creating an archive of the Chrome App.
  context.log('Creating build ${version}');
  String filename = 'spark-${version}.zip';
  archive(context, filename);
  context.log('Created ${filename}');

  WebStoreClient client =
      new WebStoreClient(appID, clientID, clientSecret, refreshToken);
  context.log('Authenticating...');
  return client.requestToken().then((e) {
    context.log('Uploading ${filename}...');
    return client.uploadItem('dist/${filename}').then((e) {
      context.log('Publishing...');
      return client.publishItem().then((e) {
        context.log('Published');
      });
    });
  });
}

// Creates an archive of the Chrome App.
//
// Sources must be pre-compiled to Javascript using "deploy" task.
//
// Will create an archive using the contents of build/deploy-out:
// - Copy the compiled sources to build/chrome-app
// - Clean all packages/ folders that have been duplicated into every
//   folders by the "compile" task
// - Copy the packages/ directory to build/chrome-app/packages
// - Remove test
// - Zip the content of build/chrome-app to dist/spark.zip
void archive(GrinderContext context, [String outputZip]) {
  final String sparkZip = outputZip == null ? '${DIST_DIR.path}/spark.zip' :
                                              '${DIST_DIR.path}/${outputZip}';
  _delete(sparkZip);
  _zip(context, 'build/deploy-out/web', sparkZip);
  _printSize(context, getFile(sparkZip));
}

void docs(GrinderContext context) {
  FileSet docFiles = new FileSet.fromDir(
      new Directory('docs'), pattern: '*.html');
  FileSet sourceFiles = new FileSet.fromDir(
      new Directory('app'), pattern: '*.dart', recurse: true);

  if (!docFiles.upToDate(sourceFiles)) {
    runSdkBinary(context, 'dartdoc',
        arguments: ['--omit-generation-time', '--no-code',
                    '--mode', 'static',
                    '--package-root', 'packages/',
                    '--include-lib', 'spark,spark.ace,spark.utils,spark.preferences,spark.workspace,spark.sdk',
                    '--include-lib', 'spark.server,spark.tcp',
                    '--include-lib', 'git,git.objects,git.zlib',
                    'app/spark_polymer.dart']);
    _zip(context, 'docs', '${DIST_DIR.path}/spark-docs.zip');
  }
}

void stats(GrinderContext context) {
  StatsCounter stats = new StatsCounter();
  stats.collect(getDir('..'));
  context.log(stats.toString());
}

/**
 * Create the 'app/sdk/dart-sdk.bin' file from the current Dart SDK.
 */
void createSdk(GrinderContext context) {
  Directory srcSdkDir = sdkDir;
  Directory destSdkDir = new Directory('app/sdk');

  destSdkDir.createSync();

  File versionFile = joinFile(srcSdkDir, ['version']);
  File destArchiveFile = joinFile(destSdkDir, ['dart-sdk.bin']);

  // copy files over
  context.log('copying SDK');
  copyDirectory(joinDir(srcSdkDir, ['lib']), joinDir(destSdkDir, ['lib']), context);

  // Get rid of some big directories we don't use.
  _delete('app/sdk/lib/_internal/compiler', context);
  _delete('app/sdk/lib/_internal/dartdoc', context);

  context.log('creating SDK archive');
  _createSdkArchive(versionFile, joinDir(destSdkDir, ['lib']), destArchiveFile);

  deleteEntity(joinDir(destSdkDir, ['lib']), context);
}

/**
 * Delete all generated artifacts.
 */
void clean(GrinderContext context) {
  // Delete the sdk archive.
  _delete('app/sdk/dart-sdk.bin');

  // Delete any compiled js output.
  for (FileSystemEntity entity in getDir('app').listSync()) {
    if (entity is File) {
      String ext = fileExt(entity);

      if (ext == 'js.map' || ext == 'js.deps' ||
          ext == 'dart.js' || ext == 'dart.precompiled.js') {
        entity.deleteSync();
      }
    }
  }

  // Delete the build/ dir.
  deleteEntity(BUILD_DIR);

  // Remove any symlinked packages that may have snuck into app/.
  for (var entity in getDir('app').listSync(recursive: true, followLinks: false)) {
    if (entity is Link && fileName(entity) == 'packages') {
      entity.deleteSync();
    }
  }
}

void _zip(GrinderContext context, String dirToZip, String destFile) {
  final String destPath = path.relative(destFile, from: dirToZip);

  if (Platform.isWindows) {
    try {
      // 7z a -r '${destFile}'
      runProcess(
          context,
          '7z',
          arguments: ['a', '-r', destPath, '.'],
          workingDirectory: dirToZip,
          quiet: true);
    } on ProcessException catch(e) {
      context.fail("Unable to execute 7z.\n"
        "Please install 7zip. Add 7z directory to the PATH environment variable.");
    }
  } else {
    // zip '${destFile}' . -r -q -x .*
    runProcess(
        context,
        'zip',
        arguments: [destPath, '.', '-qr', '-x', '.*'],
        workingDirectory: dirToZip);
  }
}

void _polymerDeploy(GrinderContext context, Directory sourceDir, Directory destDir) {
  deleteEntity(getDir('${sourceDir.path}'), context);
  deleteEntity(getDir('${destDir.path}'), context);

  // Copy spark/widgets to spark/ide/build/widgets. This is necessary because
  // spark_widgets is a relative "path" dependency in pubspec.yaml.
  copyDirectory(getDir('../widgets'), joinDir(BUILD_DIR, ['widgets']), context);

  // Copy the app directory to target/web.
  copyFile(getFile('pubspec.yaml'), sourceDir);
  copyFile(getFile('pubspec.lock'), sourceDir);
  copyDirectory(getDir('app'), joinDir(sourceDir, ['web']), context);

  deleteEntity(joinFile(destDir, ['web', 'spark_polymer.dart.precompiled.js']), context);

  deleteEntity(getDir('${sourceDir.path}/web/packages'), context);
  final Link link = new Link(sourceDir.path + '/packages');
  link.createSync('../../packages');

  runDartScript(context, 'packages/polymer/deploy.dart',
      arguments: ['--out', '../../${destDir.path}'],
      packageRoot: 'packages',
      workingDirectory: sourceDir.path);
}

void _dart2jsCompile(GrinderContext context, Directory target, String filePath,
                     [bool removeSymlinks = false]) {
  _patchDartJsInterop(context);

  File scriptFile = joinFile(sdkDir, ['bin', _execName('dart2js')]);

  // Run dart2js with a custom heap size.
  _runProcess(context, scriptFile.path,
      arguments: [
        joinDir(target, [filePath]).path,
        '--package-root=packages',
        '--suppress-warnings',
        '--suppress-hints',
        '--out=' + joinDir(target, ['${filePath}.js']).path
      ],
      environment: {
        'DART_VM_OPTIONS': '--old_gen_heap_size=2048'
      }
  );

  // clean up unnecessary (and large) files
  deleteEntity(joinFile(target, ['${filePath}.js']), context);
  deleteEntity(joinFile(target, ['${filePath}.js.deps']), context);
  deleteEntity(joinFile(target, ['${filePath}.js.map']), context);

  if (removeSymlinks) {
    // de-symlink the directory
    _removePackagesLinks(context, target);

    copyDirectory(
        joinDir(target, ['..', '..', '..', 'packages']),
        joinDir(target, ['packages']),
        context);
  }

  final Link link = new Link(joinFile(target, ['${filePath}.js']).path);
  link.createSync('./${filePath}.precompiled.js');

  _printSize(context, joinFile(target, ['${filePath}.precompiled.js']));
}

/**
 * This patches the dart:js library to fix dartbug.com/15193.
 */
void _patchDartJsInterop(GrinderContext context) {
  final matchString = 'if (dartProxy == null) {';
  final replaceString = 'if (dartProxy == null || !_isLocalObject(o)) {';

  File file = joinFile(sdkDir, ['lib', 'js', 'dart2js', 'js_dart2js.dart']);

  String contents = file.readAsStringSync();

  // This depends on the SDK files being writeable.
  if (contents.contains(matchString)) {
    context.log('Patching dart:js ${fileName(file)}');

    file.writeAsStringSync(contents.replaceFirst(matchString, replaceString));
  }
}

void _changeMode({bool useTestMode: true}) {
  File file = joinFile(Directory.current, ['app', 'app.json']);
  file.writeAsStringSync('{"test-mode":${useTestMode}}');

  file = joinFile(BUILD_DIR, ['deploy', 'web', 'app.json']);
  if (file.parent.existsSync()) {
    file.writeAsStringSync('{"test-mode":${useTestMode}}');
  }

  file = joinFile(BUILD_DIR, ['deploy-out', 'web', 'app.json']);
  if (file.parent.existsSync()) {
    file.writeAsStringSync('{"test-mode":${useTestMode}}');
  }
}

// Returns the name of the current branch.
String _getBranchName() {
  return _getCommandOutput('git rev-parse --abbrev-ref HEAD');
}

// Returns the URL of the git repository.
String _getRepositoryUrl() {
  return _getCommandOutput('git config remote.origin.url');
}

// Returns the current revision identifier of the local copy.
String _getCurrentRevision() {
  return _getCommandOutput('git rev-parse HEAD').substring(0, 10);
}

// We can build a real release only if the repository is the original
// repository of spark and master is the working branch since we need to
// increase the version and commit it to the repository.
bool _canReleaseFromHere() {
  return (_getRepositoryUrl() == 'https://github.com/dart-lang/spark.git') &&
         (_getBranchName() == 'master');
}

// In case, release is performed on a non-releasable branch/repository, we just
// archive and name the archive with the revision identifier.
void _archiveWithRevision(GrinderContext context) {
  context.log('Performing archive instead.');
  String version = _getCurrentRevision();
  String filename = 'spark-rev-${version}.zip';
  archive(context, filename);
  context.log("Created ${filename}");
}

// Increase the build number in the manifest.json file. Returns the full
// version.
String _increaseBuildNumber(GrinderContext context, {bool removeKey: false}) {
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
  buildVersion++;

  version = '${majorVersion}.${buildVersion}';
  manifestDict['version'] = version;
  if (removeKey) {
    manifestDict.remove('key');
  }
  file.writeAsStringSync(new JsonPrinter().print(manifestDict));

  // It needs to be copied to compile result directory.
  copyFile(
      joinFile(Directory.current, ['app', 'manifest.json']),
      joinDir(BUILD_DIR, ['deploy-out', 'web']));

  return version;
}

String _modifyManifestWithDroneIOBuildNumber(GrinderContext context,
                                             {bool removeKey: false})
{
  String buildNumber = Platform.environment['DRONE_BUILD_NUMBER'];
  String revision = Platform.environment['DRONE_COMMIT'];
  if (buildNumber == null || revision == null) {
    context.fail("This build process must be run in a drone.io environment");
    return null;
  }

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
  int buildVersion = int.parse(buildNumber);

  version = '${majorVersion}.${buildVersion}';
  manifestDict['version'] = version;
  manifestDict['x-spark-revision'] = revision;
  if (removeKey) {
    manifestDict.remove('key');
  }
  file.writeAsStringSync(new JsonPrinter().print(manifestDict));

  // It needs to be copied to compile result directory.
  copyFile(
      joinFile(Directory.current, ['app', 'manifest.json']),
      joinDir(BUILD_DIR, ['deploy-out', 'web']));

  return version;
}

void _removePackagesLinks(GrinderContext context, Directory target) {
  target.listSync(recursive: true, followLinks: false).forEach((FileSystemEntity entity) {
    if (entity is Link && fileName(entity) == 'packages') {
      try { entity.deleteSync(); } catch (_) { }
    } else if (entity is Directory) {
      _removePackagesLinks(context, entity);
    }
  });
}

/**
 * Create an archived version of the Dart SDK.
 *
 * File format is:
 *  - sdk version, as a utf8 string (null-terminated)
 *  - file count, printed as a utf8 string
 *  - n file entries:
 *    - file path, as a UTF8 string
 *    - file length (utf8 string)
 *  - file contents appended to the archive file, n times
 */
void _createSdkArchive(File versionFile, Directory srcDir, File destFile) {
  List files = srcDir.listSync(recursive: true, followLinks: false);
  files = files.where((f) => f is File).toList();

  ByteWriter writer = new ByteWriter();

  String version = versionFile.readAsStringSync().trim();
  writer.writeString(version);
  writer.writeInt(files.length);

  String pathPrefix = srcDir.path + Platform.pathSeparator;

  for (File file in files) {
    String path = file.path.substring(pathPrefix.length);
    path = path.replaceAll(Platform.pathSeparator, '/');
    writer.writeString(path);
    writer.writeInt(file.lengthSync());
  }

  for (File file in files) {
    writer.writeBytes(file.readAsBytesSync());
  }

  destFile.writeAsBytesSync(writer.toBytes());
}

void _printSize(GrinderContext context, File file) {
  int sizeKb = file.lengthSync() ~/ 1024;
  context.log('${file.path} is ${_NF.format(sizeKb)}k');
}

void _delete(String path, [GrinderContext context]) {
  path = path.replaceAll('/', Platform.pathSeparator);

  if (FileSystemEntity.isFileSync(path)) {
    deleteEntity(getFile(path), context);
  } else {
    deleteEntity(getDir(path), context);
  }
}

void _runCommandSync(GrinderContext context, String command, {String cwd}) {
  context.log(command);

  ProcessResult result;
  if (Platform.isWindows) {
    result = Process.runSync('cmd.exe', ['/c', command], workingDirectory: cwd);
  } else {
    result = Process.runSync('/bin/sh', ['-c', command], workingDirectory: cwd);
  }

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
  if (Platform.isWindows) {
    return Process.runSync('cmd.exe', ['/c', command]).stdout.trim();
  } else {
    return Process.runSync('/bin/sh', ['-c', command]).stdout.trim();
  }
}

/**
 * Run the given executable, with optional arguments and working directory.
 */
void _runProcess(GrinderContext context, String executable,
    {List<String> arguments : const [],
     bool quiet: false,
     String workingDirectory,
     Map<String, String> environment}) {
  context.log("${executable} ${arguments.join(' ')}");

  ProcessResult result = Process.runSync(
      executable, arguments, workingDirectory: workingDirectory,
      environment: environment);

  if (!quiet) {
    if (result.stdout != null && !result.stdout.isEmpty) {
      context.log(result.stdout.trim());
    }
  }

  if (result.stderr != null && !result.stderr.isEmpty) {
    context.log(result.stderr);
  }

  if (result.exitCode != 0) {
    throw new GrinderException(
        "${executable} failed with a return code of ${result.exitCode}");
  }
}

String _execName(String name) {
  if (Platform.isWindows) {
    return name == 'dart' ? 'dart.exe' : '${name}.bat';
  }

  return name;
}

/**
 * Pretty print Json text.
 *
 * Usage:
 *     String str = new JsonPrinter().print(jsonObject);
 */
class JsonPrinter {
  String _in = '';

  JsonPrinter();

  /**
   * Given a structured, json-like object, print it to a well-formatted, valid
   * json string.
   */
  String print(dynamic json) {
    return _print(json) + '\n';
  }

  String _print(var obj) {
    if (obj is List) {
      return _printList(obj);
    } else if (obj is Map) {
      return _printMap(obj);
    } else if (obj is String) {
      return '"${obj}"';
    } else {
      return '${obj}';
    }
  }

  String _printList(List list) {
    return "[${_indent()}${list.map(_print).join(',${_newLine}')}${_unIndent()}]";
  }

  String _printMap(Map map) {
    return "{${_indent()}${map.keys.map((key) {
      return '"${key}": ${_print(map[key])}';
    }).join(',${_newLine}')}${_unIndent()}}";
  }

  String get _newLine => '\n${_in}';

  String _indent() {
    _in += '  ';
    return '\n${_in}';
  }

  String _unIndent() {
    _in = _in.substring(2);
    return '\n${_in}';
  }
}

class StatsCounter {
  int _files = 0;
  int _lines = 0;

  void collect(Directory dir) => _collectLineInfo(dir);

  int get fileCount => _files;

  int get lineCount => _lines;

  String toString() => 'Found ${_NF.format(fileCount)} Dart files and '
      '${_NF.format(lineCount)} lines of code.';

  void _collectLineInfo(Directory dir) {
    for (FileSystemEntity entity in dir.listSync(followLinks: false)) {
      if (entity is Directory) {
        if (fileName(entity) != 'packages' &&
            fileName(entity) != 'build' &&
            !fileName(entity).startsWith('.')) {
          _collectLineInfo(entity);
        }
      } else if (entity is File) {
        if (fileExt(entity) == 'dart') {
          _files++;
          _lines += _lineCount(entity);
        }
      }
    }
  }

  static int _lineCount(File file) {
    return file.readAsStringSync().split('\n').where(
        (l) => l.trim().isNotEmpty).length;
  }
}

class ByteWriter {
  List<int> _bytes = [];

  void writeString(String str) {
    writeBytes(UTF8.encoder.convert(str));
    _bytes.add(0);
  }

  void writeInt(int val) => writeString(val.toString());

  void writeBytes(List<int> data) => _bytes.addAll(data);

  List<int> toBytes() => _bytes;
}
