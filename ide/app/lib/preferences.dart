// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.preferences;

import 'dart:async';

import 'package:chrome_gen/chrome_app.dart' as chrome_gen;

/**
 * A persistent preference mechanism.
 */
class PreferenceStore {
  static PreferenceStore createLocal() => new PreferenceStore._(chrome_gen.storage.local);
  static PreferenceStore createSync() => new PreferenceStore._(chrome_gen.storage.sync);

  StreamController<PreferenceEvent> _streamController =
      new StreamController.broadcast();

  chrome_gen.StorageArea _storageArea;

  PreferenceStore._(this._storageArea);

  /**
   * Get the value for the given key. The value is returned as a [Future].
   */
  Future<String> getValue(String key){
    return _storageArea.get(key).then((Map<String, String> map) {
      return map == null ? null : map[key];
    });
  }

  /**
   * Set the value for the given key. The returned [Future] has the same value
   * as [value] on success.
   */
  Future<String> setValue(String key, String value) {
    Map<String, String> map = {key:value};

    return _storageArea.set(map).then((_) {
      _streamController.add(new PreferenceEvent(this, key, value));
      return value;
    });
  }

  /**
   * Flush any unsaved changes to this [PreferenceStore].
   */
  void flush() {
    // TODO: implement this if needed or else remove
  }

  Stream<PreferenceEvent> get onPreferenceChange => _streamController.stream;
}

/**
 * A event class for preference changes.
 */
class PreferenceEvent {
  final PreferenceStore store;
  final String key;
  final String value;

  PreferenceEvent(this.store, this.key, this.value);
}
