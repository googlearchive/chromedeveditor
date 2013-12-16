// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A preferences implementation. [PreferenceStore] is the abstract definition of
 * a preference store. [localStore] and [syncStore] are concrete implementations
 * backed by `chrome.storage.local` and 'chrome.storage.sync` respectively.
 *
 * [MapPreferencesStore] is an implementation backed by a [Map].
 */
library spark.preferences;

import 'dart:async';
import 'dart:convert' show JSON;

import 'package:chrome_gen/chrome_app.dart' as chrome;

/**
 * A PreferenceStore backed by `chome.storage.local`.
 */
PreferenceStore localStore = new _ChromePreferenceStore(
    chrome.storage.local, 'local', new Duration(seconds: 2));

/**
 * A PreferenceStore backed by `chome.storage.sync`.
 */
PreferenceStore syncStore = new _ChromePreferenceStore(
    chrome.storage.sync, 'sync', new Duration(seconds: 6));

/**
 * A persistent preference mechanism.
 */
abstract class PreferenceStore {
  /**
   * Whether this preference store has any unwritten changes.
   */
  bool get isDirty;

  /**
   * Get the value for the given key. The value is returned as a [Future].
   */
  Future<String> getValue(String key);
  
  /**
   * Gets the value for the given key which was stored as a JSON encoded value.
   * The semantics for encoding the object as a JSON string are the same as
   * those of the [JSON.encode] method.
   * 
   * If [:defaultValue:] is provided, the value is used if there is no current
   * value stored for the given key
   */
  Future<dynamic> getJsonValue(String key, 
      { reviver(var key, var value): null, dynamic ifAbsent() });
  
  

  /**
   * Set the value for the given key. The returned [Future] has the same value
   * as [value] on success.
   */
  Future<String> setValue(String key, String value);
  
  /**
   * Sets the value encoded for the given key
   * The semantics for encoding the value as a JSON object are the same as for
   * the [JSON] converter.
   * The returned future has the encoded representation of [value] on
   * success.
   */
  Future<String> setJsonValue(String key, dynamic value, {dynamic toEncodable(var object) : null });

  /**
   * Flush any unsaved changes to this [PreferenceStore].
   */
  void flush();

  Stream<PreferenceEvent> get onPreferenceChange;
}

abstract class JsonStoreMixin {
  Future<String> getValue(String key);
  Future<String> setValue(String key, String value);
  
  /**
   * Returns a preference stored as a JSON object
   */
  Future<dynamic> getJsonValue(String key, {reviver(var key, var value) : null, ifAbsent()}) {
    return getValue(key).then((value) {
      if (value == null) {
        if (ifAbsent != null) {
          return ifAbsent();
        }
        return value;
      }
      return JSON.decode(value, reviver: reviver);
    });
  }
  
  /**
   * Sets a preference to the given value.
   * The semantics of the encoding are the same as for the [JSON] object in `dart:convert`
   */
  Future<String> setJsonValue(String key, dynamic value, {dynamic toEncodable(var object) : null }) {
    var jsonString;
    try {
      jsonString = JSON.encode(value, toEncodable: toEncodable);
    } catch (e) {
      return new Future.error(e, e.stackTrace);
    }
    return setValue(key, jsonString);
  }
}

/**
 * A [PreferenceStore] implementation based on a [Map].
 */
class MapPreferencesStore 
    extends Object with JsonStoreMixin 
    implements PreferenceStore {
  Map _map = {};
  bool _dirty = false;
  StreamController<PreferenceEvent> _controller = new StreamController.broadcast();

  bool get isDirty => _dirty;

  Future<String> getValue(String key) => new Future.value(_map[key]);

  Future<String> setValue(String key, String value) {
    _dirty = true;
    _map[key] = value;
    _controller.add(new PreferenceEvent(this, key, value));
    return new Future.value(_map[key]);
  }

  void flush() {
    _dirty = false;
  }

  Stream<PreferenceEvent> get onPreferenceChange => _controller.stream;
}

/**
 * A [PreferenceStore] implementation based on `chrome.storage`.
 *
 * This preferences implementation will automatically flush any dirty changes
 * out to `chrome.storage` periodically.
 */
class _ChromePreferenceStore 
    extends Object with JsonStoreMixin 
    implements PreferenceStore {
  chrome.StorageArea _storageArea;
  Duration _flushInterval;
  Map _map = {};
  StreamController<PreferenceEvent> _controller = new StreamController.broadcast();
  Timer _timer;

  _ChromePreferenceStore(this._storageArea, String name, this._flushInterval) {
    chrome.storage.onChanged.listen((chrome.StorageOnChangedEvent event) {
      if (event.areaName == name) {
        for (String key in event.changes.keys) {
          Map changeMap = event.changes[key];

          // We only understand strings.
          var change = changeMap['newValue'].toString();
          _controller.add(new PreferenceEvent(this, key, change));
        }
      }
    });
  }

  bool get isDirty => _map.isNotEmpty;

  /**
   * Get the value for the given key. The value is returned as a [Future].
   */
  Future<String> getValue(String key) {
    if (_map.containsKey(key)) {
      return new Future.value(_map[key]);
    } else {
      return _storageArea.get(key).then((Map<String, String> map) {
        return map == null ? null : map[key];
      });
    }
  }

  /**
   * Set the value for the given key. The returned [Future] has the same value
   * as [value] on success.
   */
  Future<String> setValue(String key, String value) {
    _map[key] = value;
    _controller.add(new PreferenceEvent(this, key, value));

    _startTimer();

    return new Future.value(_map[key]);
  }

  /**
   * Flush any unsaved changes to this [PreferenceStore].
   */
  void flush() {
    if (_map.isNotEmpty) {
      _storageArea.set(_map);
      _map.clear();
    }

    if (_timer != null) {
      _timer.cancel();
      _timer = null;
    }
  }

  Stream<PreferenceEvent> get onPreferenceChange => _controller.stream;

  void _startTimer() {
    // Flush dirty preferences periodically.
    if (_timer == null) {
      _timer = new Timer(_flushInterval, flush);
    }
  }
}

/**
 * A event class for preference changes.
 */
class PreferenceEvent {
  final PreferenceStore store;
  final String key;
  final String value;

  PreferenceEvent(this.store, this.key, this.value);
  
  /**
   * Decodes value as if it were a stored JSON string using the specified [:reviver:]
   * If [:ifAbsent:] is provided and the [value] is `null`, returns the result of
   * calling the function.
   */
  valueAsJson({reviver(var key, var value): null, ifAbsent(): null }) {
    if (value == null && ifAbsent != null) {
      return ifAbsent();
    }
    return JSON.decode(value, reviver: reviver);
  }
      
}
