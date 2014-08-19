// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.app.manifest_builder;

import 'dart:async';

import '../json/json_parser.dart';
import '../json/json_validator.dart';
import '../json/json_utils.dart';
import '../builder.dart';
import '../jobs.dart';
import '../workspace.dart';
import 'app_manifest_validator.dart';

class AppManifestProperties {
  final String packageSpecFileName = "manifest.json";
  final String jsonErrorMarkerType = "manifest_json.syntax";
  final int jsonErrorMarkerSeverity = Marker.SEVERITY_ERROR;
  final String validationErrorMarkerType = "manifest_json.semantics";
  final int validatorErrorMarkerSeverity = Marker.SEVERITY_WARNING;
}

final appManifestProperties = new AppManifestProperties();

/**
 * Implementation of [ErrorSink] for a [File] instance.
 */
class FileErrorSink implements ErrorSink {
  final File file;
  final String markerType;
  final int markerSeverity;
  final StringLineOffsets lineOffsets;

  FileErrorSink(
      this.file,
      String contents,
      this.markerType,
      this.markerSeverity)
      : this.lineOffsets = new StringLineOffsets(contents) {
    file.clearMarkers(markerType);
  }

  void emitMessage(Span span, String message) {
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
      ErrorSink jsonErrorSink = new FileErrorSink(
          file,
          contents,
          appManifestProperties.jsonErrorMarkerType,
          appManifestProperties.jsonErrorMarkerSeverity);
      ErrorSink manifestErrorSink = new FileErrorSink(
          file,
          contents,
          appManifestProperties.validationErrorMarkerType,
          appManifestProperties.validatorErrorMarkerSeverity);

      try {
        // TODO(rpaquay): Should we report errors if the file is empty?
        if (contents.trim().isNotEmpty) {
          JsonValidatorListener listener = new JsonValidatorListener(
              jsonErrorSink, new AppManifestValidator(manifestErrorSink));
          JsonParser parser = new JsonParser(contents, listener);
          parser.parse();
        }
      } on FormatException catch (e) {
        // Ignore e; already reported through the listener interface.
      }
    });
  }
}
