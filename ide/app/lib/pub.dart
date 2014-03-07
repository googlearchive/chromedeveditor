// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 *  Pub services
 */
library spark.pub;

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:tavern/tavern.dart' as tavern;

import 'utils.dart';
import 'workspace.dart';


class PubManager {
  
  Notifier _notifier;
  
  Logger _logger = new Logger('spark.pub');
  
  PubManager([this._notifier]) {
    if (_notifier == null) {
       _notifier = new NullNotifier();
    }
  }
  
  Future runPubGet(Project project) {
    return tavern.getDependencies(project.entry, _handlePubLog).whenComplete(() {
      return project.refresh();
    }).catchError((e, st) {   
      _logger.severe('Error Running Pub Get', e, st);
      return new Future.error(e, st);
    });
  }
  
  void _handlePubLog(String line, String level) {
    // TODO: Dial the logging back.
     _logger.info(line);
  }
  
}
