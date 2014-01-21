// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.dart_builder;

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
        file.workspace.pauseMarkerStream();

        try {
          file.clearMarkers();

          for (AnalysisError error in result.errors) {
            LineInfo_Location location = result.getLineInfo(error);

            file.createMarker(
                'dart', _convertSeverity(error.errorCode.errorSeverity),
                error.message, location.lineNumber,
                error.offset, error.offset + error.length);
          }
        } finally {
          file.workspace.resumeMarkerStream();
        }
      });
    });
  }
}

int _convertSeverity(ErrorSeverity sev) {
  if (sev == ErrorSeverity.ERROR) {
    return Marker.SEVERITY_ERROR;
  } else  if (sev == ErrorSeverity.WARNING) {
    return Marker.SEVERITY_WARNING;
  } else  if (sev == ErrorSeverity.INFO) {
    return Marker.SEVERITY_INFO;
  } else {
    return Marker.SEVERITY_NONE;
  }
}
