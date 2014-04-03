// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.json_builder;

import 'dart:async';

import 'package:json/json.dart';

import '../builder.dart';
import '../jobs.dart';
import '../workspace.dart';

/**
 * A [Builder] implementation to add validation warnings to JSON files.
 */
class JsonBuilder extends Builder {

  @override
  Future build(ResourceChangeEvent event, ProgressMonitor monitor) {
    List<ChangeDelta> changes = event.changes.where(
        (c) => c.resource is File && _includeFile(c.resource)).toList();

    if (changes.isEmpty) return new Future.value();

    Iterable futures = changes.map((c) => _handleFileChange(c.resource));

    return Future.wait(futures);
  }

  bool _includeFile(File file) {
    return file.name.endsWith('.json') && !file.isDerived();
  }

  Future _handleFileChange(File file) {
    return file.getContents().then((String str) {
      file.clearMarkers('json');

      try {
        JsonParser parser = new JsonParser(str, new _JsonParserListener(file));
        parser.parse();
      } catch (e) {
        // Ignore e; already reported through the listener interface.
      }
    });
  }
}

class _JsonParserListener extends JsonListener {
  final File file;

  _JsonParserListener(this.file);

  void fail(String source, int position, String message) {
    int lineNum = _calcLineNumber(source, position);
    file.createMarker('json', Marker.SEVERITY_ERROR, message, lineNum, position);
  }

  /**
   * Count the newlines between 0 and position.
   */
  int _calcLineNumber(String source, int position) {
    int lineCount = 0;

    for (int index = 0; index < source.length; index++) {
      if (source[index] == '\n') lineCount++;
      if (index == position) return lineCount + 1;
    }

    return lineCount;
  }
}
