// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.state;

import 'dart:async';

import 'package:chrome/chrome_app.dart' as chrome;

/**
 * A manager for persistent UI state.
 */
abstract class StateManager {
  dynamic getState(String key);
  void setState(String key, dynamic data);
}

/**
 * A [StateManager] implementation backed by `chrome.storage.local`.
 */
class LocalStateManager extends StateManager {
  static Future<LocalStateManager> create() {
    return chrome.storage.local.get(null).then((map) {
      return new LocalStateManager._(map);
    });
  }

  final Map _map;

  LocalStateManager._(this._map);

  dynamic getState(String key) => _map[key];

  void setState(String key, dynamic data) {
    _map[key] = data;
    chrome.storage.local.set({key: data});
  }
}
