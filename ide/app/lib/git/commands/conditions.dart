// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.utils;

import 'dart:async';

import 'package:chrome/chrome_app.dart' as chrome;

import '../objectstore.dart';

class Conditions {

  static Future<GitConfig> checkForUncommittedChanges(chrome.DirectoryEntry dir,
      ObjectStore store) {
    //TODO(grv) : implement.
    return new Future.value();
  }

}
