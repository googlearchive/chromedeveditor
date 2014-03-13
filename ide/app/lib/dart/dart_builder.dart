// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.dart_builder;

import 'dart:async';

import '../builder.dart';
import '../jobs.dart';
import '../services.dart';
import '../workspace.dart';

/**
 * A [Builder] implementation that drives the Dart analyzer.
 */
class DartBuilder extends Builder {
  Services services;

  DartBuilder(this.services);

  Future build(ResourceChangeEvent event, ProgressMonitor monitor) {
    List<File> files = event.modifiedFiles.where(
        (file) => file.name.endsWith('.dart')).toList();

    if (files.isEmpty) return new Future.value();

    AnalyzerService analyzer = services.getService("analyzer");

    return analyzer.buildFiles(files).then((Map<File, List<AnalysisError>> errors) {
      Workspace workspace = files.first.workspace;

      workspace.pauseMarkerStream();

      try {
        files.forEach((f) => f.clearMarkers('dart'));

        for (File file in errors.keys) {
          for (AnalysisError error in errors[file]) {
            file.createMarker('dart',
                _convertSeverity(error.errorSeverity),
                error.message, error.lineNumber,
                error.offset, error.offset + error.length);
          }
        }
      } finally {
        workspace.resumeMarkerStream();
      }
    });
  }
}

int _convertSeverity(int sev) {
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
