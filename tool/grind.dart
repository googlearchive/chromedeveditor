
import 'dart:io';

import 'package:grinder/grinder.dart';

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
}

void compile(GrinderContext context) {
//  // TODO: check outputs
//  FileSet sparkSource = new FileSet.fromFile(new File('app/spark.dart'));
//  FileSet output = new FileSet.fromFile(new File('app/spark.dart.js'));
//
//  if (!output.upToDate(sparkSource)) {
    // We tell dart2js to compile to spark.dart.js; it also outputs a CSP
    // version (spark.dart.precompiled.js), which is what we actually use.
    runProcess(context, 'dart2js', arguments: [
        'app/spark.dart', '--out=app/spark.dart.js']);
    int sizeKb = new File('app/spark.dart.precompiled.js').lengthSync() ~/ 1024;
    context.log('app/spark.dart.precompiled.js is ${sizeKb}kb');
//  }
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
