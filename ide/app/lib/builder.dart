// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * TODO:
 */
library spark.builder;

import 'dart:async';

import 'package:logging/logging.dart';

import 'workspace.dart';
import 'jobs.dart';

final Logger _logger = new Logger('spark.builder');

/**
 * TODO:
 */
class BuilderManager {
  final Workspace workspace;
  final JobManager jobManager;

  List<Builder> builders = [];

  List<ResourceChangeEvent> _events = [];

  Timer _timer;
  bool _buildRunning = false;

  BuilderManager(this.workspace, this.jobManager) {
    workspace.onResourceChange.listen(_handleChange);
  }

  bool get isRunning => _buildRunning;

  void _handleChange(ResourceChangeEvent event) {
    _events.add(event);

    if (!_buildRunning) {
      _startTimer();
    }
  }

  void _startTimer() {
    // Bundle up changes for ~50ms.
    if (_timer != null) _timer.cancel();
    _timer = new Timer(new Duration(milliseconds: 50), _runBuild);
  }

  void _runBuild() {
    // TODO: this should run in a job
    List buildersCopy = builders.toList(growable: false);
    List eventsCopy = _events.toList(growable: false);

    _events.clear();
    _buildRunning = true;

    Future.forEach(buildersCopy, (Builder builder) {
      builder.build(eventsCopy);
    }).then((_) {
      _buildRunning = false;
      if (_events.isNotEmpty) _startTimer();
    }).catchError((e) {
      _logger.log(Level.SEVERE, 'Exception from builder', e);
    });
  }
}

/**
 * TODO:
 */
abstract class Builder {

  // TODO:
  Future build(List<ResourceChangeEvent> changes);

}
