// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.dart_builder;

import 'dart:async';

import 'package:logging/logging.dart';

import '../builder.dart';
import '../jobs.dart';
import '../services.dart';
import '../workspace.dart';

final _disableDartAnalyzer = false;

Logger _logger = new Logger('spark.dart_builder');

/**
 * A [Builder] implementation that drives the Dart analyzer.
 */
class DartBuilder extends Builder {
  Services services;

  DartBuilder(this.services);

  Future build(ResourceChangeEvent event, ProgressMonitor monitor) {
    List<ChangeDelta> changes = event.changes.where(
        (c) => c.resource is File && c.resource.name.endsWith('.dart')).toList();

    if (_disableDartAnalyzer || changes.isEmpty) return new Future.value();

    Project project = changes.first.resource.project;

    List<File> addedFiles = changes.where(
        (c) => c.isAdd).map((c) => c.resource).toList();
    List<File> changedFiles = changes.where(
        (c) => c.isChange).map((c) => c.resource).toList();
    List<File> deletedFiles = changes.where(
        (c) => c.isDelete).map((c) => c.resource).toList();

    AnalyzerService analyzer = services.getService("analyzer");
    ProjectAnalyzer context = analyzer.getProjectAnalyzer(project);

    if (context == null) {
      // Send in all the existing files for the project in order to properly set
      // up the new context.
      addedFiles = project.traverse().where(
          (r) => r.isFile && r.name.endsWith('.dart')).toList();
      changedFiles = [];
      deletedFiles = [];

      // TODO(devoncarew): Temporarily, short-circuit large projects.
      if (addedFiles.length > 100) {
        _logger.warning('Dart analysis is disabled for large projects.');
        return new Future.value();
      }

      context = analyzer.createProjectAnalyzer(project);
    }

    return context.processChanges(addedFiles, changedFiles, deletedFiles).then(
        (AnalysisResult result) {
      project.workspace.pauseMarkerStream();

      try {
        for (File file in result.getFiles()) {
          file.clearMarkers('dart');

          for (AnalysisError error in result.getErrorsFor(file)) {
            file.createMarker('dart',
                _convertSeverity(error.errorSeverity),
                error.message, error.lineNumber,
                error.offset, error.offset + error.length);
          }
        }
      } finally {
        project.workspace.resumeMarkerStream();
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
