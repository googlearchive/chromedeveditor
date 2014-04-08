// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.dart_builder;

import 'dart:async';

import 'package:logging/logging.dart';

import 'pub.dart';
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
  final Services services;

  DartBuilder(this.services);

  Future build(ResourceChangeEvent event, ProgressMonitor monitor) {
    if (_disableDartAnalyzer) return new Future.value();

    List<ChangeDelta> changes = event.changes.where(
        (c) => c.resource is File && _includeFile(c.resource)).toList();
    List<ChangeDelta> projectDeletes = event.changes.where(
        (c) => c.resource is Project && c.isDelete).toList();

    AnalyzerService analyzer = services.getService("analyzer");

    if (projectDeletes.isNotEmpty) {
      // If we get a project delete, it'll be the only thing that we have to
      // process.
      Project project = projectDeletes.first.resource;
      ProjectAnalyzer context = analyzer.getProjectAnalyzer(project);

      if (context != null) {
        analyzer.disposeProjectAnalyzer(context);
      }

      return new Future.value();
    } else if (changes.isEmpty) {
      return new Future.value();
    } else {
      Project project = changes.first.resource.project;

      List<File> addedFiles = changes.where(
          (c) => c.isAdd).map((c) => c.resource).toList();
      List<File> changedFiles = changes.where(
          (c) => c.isChange).map((c) => c.resource).toList();
      List<File> deletedFiles = changes.where(
          (c) => c.isDelete).map((c) => c.resource).toList();

      ProjectAnalyzer context = analyzer.getProjectAnalyzer(project);

      if (context == null) {
        // Send in all the existing files for the project in order to properly set
        // up the new context.
        addedFiles = project.traverse().where(
            (r) => r.isFile && r.name.endsWith('.dart')).toList();
        changedFiles = [];
        deletedFiles = [];

        context = analyzer.createProjectAnalyzer(project);
      }

      _removeSecondaryPackages(addedFiles);
      _removeSecondaryPackages(changedFiles);
      _removeSecondaryPackages(deletedFiles);

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

  bool _includeFile(File file) {
    return file.name.endsWith('.dart') && !file.isDerived();
  }
}

void _removeSecondaryPackages(List<File> files) {
  files.removeWhere((file) {
    return file.path.contains('/$PACKAGES_DIR_NAME/') && !isInPackagesFolder(file);
  });
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
