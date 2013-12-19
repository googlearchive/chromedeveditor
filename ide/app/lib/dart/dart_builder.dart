// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This library contains [BuilderManager] and the abstract [Builder] class.
 * These classes are used to batch process resource change events.
 */
library spark.dart.dart_builder;

import 'dart:async';

import '../builder.dart';
import '../jobs.dart';
import '../workspace.dart';

/**
 * A [Builder] implementation that drives the Dart analyzer.
 */
class DartBuilder extends Builder {

  Future build(ResourceChangeEvent event, ProgressMonitor monitor) {
    Iterable<File> files = event.changes.where((ChangeDelta delta) {
      return !delta.isDelete
          && delta.resource is File
          && delta.resource.name.endsWith('.dart');
    }).map((delta) => delta.resource);

    if (files.isEmpty) {
      return new Future.value();
    }

    Completer completer = new Completer();

    Timer.run(() {
      files.forEach(_process);
      completer.complete();
    });

    return completer.future;
  }

  /**
   * Create markers for a `.dart` file.
   */
  void _process(File file) {
    print("builder running on ${file}");
  }
}
