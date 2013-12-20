// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.dart.dart_builder;

import 'dart:async';

import '../analyzer.dart';
import '../builder.dart';
import '../jobs.dart';
import '../workspace.dart';

/**
 * A [Builder] implementation that drives the Dart analyzer.
 */
class DartBuilder extends Builder {

  Future build(ResourceChangeEvent event, ProgressMonitor monitor) {
    Iterable<File> dartFiles = event.modifiedFiles.where(
        (file) => file.name.endsWith('.dart'));

    if (dartFiles.isEmpty) return new Future.value();

    Completer completer = new Completer();

    createSdk().then((ChromeDartSdk sdk) {
      Future.forEach(dartFiles, (file) => _processFile(sdk, file)).then((_) {
        completer.complete();
      });
    });

    return completer.future;
  }

  /**
   * Create markers for a `.dart` file.
   */
  Future _processFile(ChromeDartSdk sdk, File file) {
    return file.getContents().then((String contents) {
      return analyzeString(sdk, contents, performResolution: false).then((AnalyzerResult result) {
        // TODO: remove all dart markers for file
        //file.clearMarkers();

        for (AnalysisError error in result.errors) {
          LineInfo_Location location = result.getLineInfo(error);

          // TODO: create markers
          print('${error.errorCode.errorSeverity}'
              ': ${error.message}, line ${location.lineNumber}');
        }
      });
    });
  }
}
