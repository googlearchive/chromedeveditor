// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.app.manifest_builder;

import 'dart:async';

import '../builder.dart';
import '../jobs.dart';
import '../json/json_parser.dart';
import '../json/json_validator.dart';
import '../json/json_utils.dart';
import '../workspace.dart';
import 'app_manifest_validator.dart';

class AppManifestProperties {
  final String packageSpecFileName = "manifest.json";
  final String jsonErrorMarkerType = "manifest_json.syntax";
  final int jsonErrorMarkerSeverity = Marker.SEVERITY_ERROR;
  final String validationErrorMarkerType = "manifest_json.semantics";
  final int validationErrorMarkerSeverity = Marker.SEVERITY_WARNING;
}

final AppManifestProperties appManifestProperties = new AppManifestProperties();

/**
 * Implementation of [ErrorCollector] for a [File] instance.
 */
class FileErrorCollector implements ErrorCollector {
  final File file;
  final StringLineOffsets lineOffsets;
  final String markerType;
  final int markerSeverity;

  FileErrorCollector(
      this.file,
      this.lineOffsets,
      this.markerType,
      this.markerSeverity) {
    file.clearMarkers(markerType);
  }

  void addMessage(String messageId, Span span, String message) {
    file.createMarker(
        markerType,
        markerSeverity,
        message,
        lineOffsets.getLineColumn(span.start).line,
        span.start,
        span.end);
  }
}

/**
 * A [Builder] implementation to add validation warnings to "manifest.json"
 * files.
 */
class AppManifestBuilder extends Builder {
  @override
  Future build(ResourceChangeEvent event, ProgressMonitor monitor) {
    Iterable<ChangeDelta> changes = filterPackageChanges(event.changes);
    changes = changes.where(
        (c) => c.resource is File && _shouldProcessFile(c.resource));

    return Future.wait(changes.map((c) => _handleFileChange(c.resource)));
  }

  bool _shouldProcessFile(File file) {
    return file.name == appManifestProperties.packageSpecFileName &&
        !file.isDerived();
  }

  Future _handleFileChange(File file) {
    // TODO(rpaquay): The work below should be performed in a [Service] to
    // avoid blocking UI.
    return file.getContents().then((String contents) {
      StringLineOffsets lineOffsets = new StringLineOffsets(contents);
      ErrorCollector jsonErrorCollector = new FileErrorCollector(
          file,
          lineOffsets,
          appManifestProperties.jsonErrorMarkerType,
          appManifestProperties.jsonErrorMarkerSeverity);
      ErrorCollector validationErrorCollector = new FileErrorCollector(
          file,
          lineOffsets,
          appManifestProperties.validationErrorMarkerType,
          appManifestProperties.validationErrorMarkerSeverity);

      try {
        // TODO(rpaquay): Should we report errors if the file is empty?
        if (contents.trim().isNotEmpty) {
          JsonValidatorListener listener = new JsonValidatorListener(
              jsonErrorCollector,
              new AppManifestValidator(validationErrorCollector));
          JsonParser parser = new JsonParser(contents, listener);
          parser.parse();
        }
      } on FormatException catch (e) {
        // Ignore e; already reported through the listener interface.
      }
    });
  }
}
