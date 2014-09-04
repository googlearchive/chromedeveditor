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
    List<ChangeDelta> changes = event.changes.where(
        (c) => c.resource is File && _includeFile(c.resource)).toList();
    List<ChangeDelta> projectDeletes = event.changes.where(
        (c) => c.resource is Project && c.isDelete).toList();

    if (projectDeletes.isNotEmpty) {
      // If we get a project delete, it'll be the only thing that we have to
      // process.
      Project project = projectDeletes.first.resource;

      if (analyzer.hasProjectAnalyzer(project)) {
        analyzer.disposeProjectAnalyzer(project);
      }

      return new Future.value();
    } else if (changes.isEmpty) {
      return new Future.value();
    } else {
      Project project = changes.first.resource.project;

      // Guard against a `null` project.
      if (project == null) return new Future.value();

      if (!analyzer.hasProjectAnalyzer(project)) {
        return analyzer.getCreateProjectAnalyzer(project);
      } else {
        List<File> addedFiles = changes.where(
            (c) => c.isAdd).map((c) => c.resource).toList();
        List<File> changedFiles = changes.where(
            (c) => c.isChange).map((c) => c.resource).toList();
        List<File> deletedFiles = changes.where(
            (c) => c.isDelete).map((c) => c.resource).toList();

        bool hasNewPackageFiles = addedFiles.any(
            (r) => analyzer.getPackageManager().properties.isInPackagesFolder(r));

        if (hasNewPackageFiles) {
          // We currently need to tear down the analysis context and build a
          // new one.
          _logger.info('packages/ changes detected; bouncing analysis context');

          return analyzer.disposeProjectAnalyzer(project).then((_) {
            return analyzer.getCreateProjectAnalyzer(project);
          });
        } else {
          _removeSecondaryPackages(addedFiles);
          _removeSecondaryPackages(changedFiles);
          _removeSecondaryPackages(deletedFiles);

          return analyzer.getCreateProjectAnalyzer(project).then((context) {
            return context.processChanges(addedFiles, changedFiles, deletedFiles);
          });
        }
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
