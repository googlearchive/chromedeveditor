// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.json_builder;

import 'dart:async';


import '../apps/app_manifest_builder.dart';
import '../builder.dart';
import '../jobs.dart';
import '../workspace.dart';
import '../package_mgmt/bower_properties.dart';
import 'json_parser.dart';
import 'json_utils.dart';

/**
 * A [Builder] implementation to add validation warnings to JSON files.
 */
class JsonBuilder extends Builder {

  @override
  Future build(ResourceChangeEvent event, ProgressMonitor monitor) {
    Iterable<ChangeDelta> changes = filterPackageChanges(event.changes);
    changes = changes.where(
        (c) => c.resource is File && _shouldProcessFile(c.resource));

    return Future.wait(changes.map((c) => _handleFileChange(c.resource)));
  }

  bool _shouldProcessFile(File file) {
    // There's a more specific builder for bower.
    if (file.name == bowerProperties.packageSpecFileName) return false;
    if (file.name == appManifestProperties.packageSpecFileName) return false;

    return file.name.endsWith('.json') && !file.isDerived();
  }

  Future _handleFileChange(File file) {
    return file.getContents().then((String str) {
      file.clearMarkers('json');

      try {
        if (str.trim().isNotEmpty) {
          StringLineOffsets lineOffsets = new StringLineOffsets(str);
          JsonParser parser = new JsonParser(
              str, new _JsonParserListener(file, lineOffsets));
          parser.parse();
        }
      } catch (e) {
        // Ignore e; already reported through the listener interface.
      }
    });
  }
}

class _JsonParserListener extends JsonListener {
  final File file;
  final StringLineOffsets lineOffsets;

  _JsonParserListener(this.file, this.lineOffsets);

  void fail(String source, Span span, String message) {
    int lineNum = lineOffsets.getLineColumn(span.start).line;
    file.createMarker('json', Marker.SEVERITY_ERROR, message, lineNum, span.start, span.end);
  }
}
