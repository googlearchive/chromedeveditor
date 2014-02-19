// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A library to expose the `chrome.developerPrivate` API.
 */
library spark.developerPrivate;

import 'dart:async';
import 'dart:js';

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:chrome/src/common.dart';

final ChromeDeveloperPrivate developerPrivate = new ChromeDeveloperPrivate._();

class ChromeDeveloperPrivate {
  static final JsObject _developerPrivate = context['chrome']['developerPrivate'];

  ChromeDeveloperPrivate._();

  /**
   * Returns the application ID.
   */
  Future<String> loadDirectory(chrome.DirectoryEntry directory) {
    chrome.ChromeObject dir = directory as chrome.ChromeObject;
    var completer = new ChromeCompleter<String>.oneArg();
    _developerPrivate.callMethod(
        'loadDirectory', [dir.jsProxy, completer.callback]);
    return completer.future;
  }

  /**
   * Returns information of all the extensions and apps installed. Set
   * [include_disabled] to true to include disabled items; set
   * [include_terminated] to true to include terminated items.
   */
  Future<List<Map>> getItemsInfo(bool include_disabled, bool include_terminated) {
    var completer = new ChromeCompleter<String>.oneArg(listify);
    _developerPrivate.callMethod('getItemsInfo',
        [include_disabled, include_terminated, completer.callback]);
    return completer.future;
  }
}
