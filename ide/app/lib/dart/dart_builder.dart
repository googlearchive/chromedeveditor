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
  final Services services;
  AnalyzerService analyzer;

  DartBuilder(this.services) {
    analyzer = services.getService("analyzer");
  }

  Future build(ResourceChangeEvent event, ProgressMonitor monitor) {
    if (_disableDartAnalyzer) return new Future.value();

    List<ChangeDelta> changes = event.changes.where(
        (c) => c.resource is File && _includeFile(c.resource)).toList();
    List<ChangeDelta> projectDeletes = event.changes.where(
        (c) => c.resource is Project && c.isDelete).toList();

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

      ProjectAnalyzer context = analyzer.getProjectAnalyzer(project);

      if (context == null) {
        return analyzer.createProjectAnalyzer(project);
      } else {
        List<File> addedFiles = changes.where(
            (c) => c.isAdd).map((c) => c.resource).toList();
        List<File> changedFiles = changes.where(
            (c) => c.isChange).map((c) => c.resource).toList();
        List<File> deletedFiles = changes.where(
            (c) => c.isDelete).map((c) => c.resource).toList();

        _removeSecondaryPackages(addedFiles);
        _removeSecondaryPackages(changedFiles);
        _removeSecondaryPackages(deletedFiles);

        return context.processChanges(addedFiles, changedFiles, deletedFiles);
      }
    }
  }

  bool _includeFile(File file) {
    return file.name.endsWith('.dart') && !file.isDerived();
  }

  void _removeSecondaryPackages(List<File> files) {
    files.removeWhere(
        (file) => analyzer.getPackageManager().properties.isSecondaryPackage(file));
  }
}
