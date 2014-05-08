// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.js_builder;

import 'dart:async';

import 'package:logging/logging.dart';

import 'jshint.dart';
import '../builder.dart';
import '../jobs.dart';
import '../workspace.dart';

Logger _logger = new Logger('spark.js_builder');

/**
 * A [Builder] implementation for JavaScript files.
 */
class JavaScriptBuilder extends Builder {
  JsHint linter;

  JavaScriptBuilder() {
    linter = new JsHint();
  }

  Future build(ResourceChangeEvent event, ProgressMonitor monitor) {
    List<ChangeDelta> changes = event.changes.where(
        (c) => c.resource is File && _includeFile(c.resource)).toList();
    List<ChangeDelta> projectDeletes = event.changes.where(
        (c) => c.resource is Project && c.isDelete).toList();

    if (projectDeletes.isNotEmpty) {
      // If we get a project delete, it'll be the only thing that we have to
      // process.
      return new Future.value();
    } else {
      List<File> files = event.modifiedFiles.where(_includeFile).toList();

      if (files.isEmpty) return new Future.value();

      Project project = files.first.project;

      project.workspace.pauseMarkerStream();

      return Future.forEach(files, _processFile).whenComplete(() {
        project.workspace.resumeMarkerStream();
      });
    }
  }

  bool _includeFile(File file) {
    return file.name.endsWith('.js') && !file.isDerived();
  }

  Future _processFile(File file) {
    return file.getContents().then((String source) {
      file.clearMarkers('js');
      List<JsResult> errors = linter.lint(source);

      if (errors.isNotEmpty) {
        List<int> lines = _createLineOffsets(source);
        errors.forEach((e) => _addError(file, lines, e));
      }
    });
  }

  void _addError(File file, List<int> lines, JsResult error) {
    int fileOffset = _lineStartOffset(lines, error.line) + error.column;

    int severity = Marker.SEVERITY_ERROR;
    if (error.severity == 'warning') severity = Marker.SEVERITY_WARNING;
    if (error.severity == 'info') severity = Marker.SEVERITY_INFO;

    file.createMarker('js',
        severity,
        error.message,
        error.line,
        fileOffset,
        fileOffset);
  }

  List<int> _createLineOffsets(String text) {
    List<int> result = [0];

    int len = text.length;
    bool lastWasEol = false;
    
    for (int i = 0; i < len; i++) {
      if (lastWasEol) result.add(i);
      lastWasEol = false;
      if (text[i] == '\n') lastWasEol = true;
    }

    return result;
  }

  int _lineStartOffset(List<int> lines, int line) {
    if (line < 0 || line >= lines.length) return 0;
    return lines[line];
  }
}
