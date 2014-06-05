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

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:logging/logging.dart';

final Logger _logger = new Logger('preferences');

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
 * Preferences specific to Spark.
 */
class SparkPreferences {
  PreferenceStore prefStore;
  Future onPreferencesReady;

  // [CachedPreference] subclass instance for each preference:
  BoolCachedPreference _stripWhitespaceOnSave;

  SparkPreferences(this.prefStore) {
    // Initialize each preference:
    List<CachedPreference> allPreferences = [
        _stripWhitespaceOnSave = new BoolCachedPreference(
            prefStore, "stripWhitespaceOnSave"),
        ];

    onPreferencesReady = Future.wait(allPreferences.map((p) => p.whenLoaded));
  }

  // Getters and setters for the value of each preference:
  bool get stripWhitespaceOnSave => _stripWhitespaceOnSave.value;
  set stripWhitespaceOnSave(bool value) {
    _stripWhitespaceOnSave.value = value;
  }
}

/**
 * Defines a preference with built in `whenLoaded` [Future] and easy access to
 * getting and setting (automatically saving as well as caching) the preference
 * `value`.
 */
abstract class CachedPreference<T> {
  Future<CachedPreference> whenLoaded;

  Completer _whenLoadedCompleter = new Completer<CachedPreference>();
  final PreferenceStore _prefStore;
  T _currentValue;
  String _preferenceId;

  /**
   * [prefStore] is the PreferenceStore to use and [preferenceId] is the id of
   * the stored preference.
   */
  CachedPreference(this._prefStore, this._preferenceId) {
    whenLoaded = _whenLoadedCompleter.future;
    _retrieveValue().then((_) {
      // If already loaded (preference has been saved before the load has
      // finished), don't complete.
      if (!_whenLoadedCompleter.isCompleted) {
        _whenLoadedCompleter.complete(this);
      }
    });
  }

  T adaptFromString(String value);
  String adaptToString(T value);

  /**
   * The value of the preference, if loaded. If not loaded, throws an error.
   */
  T get value {
    if (!_whenLoadedCompleter.isCompleted) {
      throw "CachedPreference value read before it was loaded";
    }
    return _currentValue;
  }

  /**
   * Sets and caches the value of the preference.
   */
  void set value(T newValue) {
    _currentValue = newValue;
    _prefStore.setValue(_preferenceId, adaptToString(newValue));

    // If a load has not happened by this point, consider us loaded.
    if (!_whenLoadedCompleter.isCompleted) {
      _whenLoadedCompleter.complete(this);
    }
  }

  Future _retrieveValue() => _prefStore.getValue(_preferenceId)
      .then((String value) => _currentValue = adaptFromString(value));
}

/**
 * Defines a cached [bool] preference access object. Automatically saves and
 * caches for performance.
 */
class BoolCachedPreference extends CachedPreference<bool> {
  BoolCachedPreference(PreferenceStore prefs, String id) : super(prefs, id);

  @override
  bool adaptFromString(String value) => value == 'true';

  @override
  String adaptToString(bool value) => value ? 'true' : 'false';
}

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
  Future<String> getValue(String key, [String defaultVal]);

  /**
   * Set the value for the given key. The returned [Future] has the same value
   * as [value] on success.
   */
  Future<String> setValue(String key, String value);

  /**
   * Removes list of items from this [PreferenceStore].
   */
  Future removeValue(List<String> keys);

  /**
   * Removes all preferences from this [PreferenceStore].
   */
  Future clear();

  /**
   * Flush any unsaved changes to this [PreferenceStore].
   */
  void flush();

  Stream<PreferenceEvent> get onPreferenceChange;
}

/**
 * A [PreferenceStore] implementation based on a [Map].
 */
class MapPreferencesStore implements PreferenceStore {
  Map _map = {};
  bool _dirty = false;
  StreamController<PreferenceEvent> _controller = new StreamController.broadcast();

  bool get isDirty => _dirty;

  Future<String> getValue(String key, [String defaultVal]) {
    final String val = _map[key];
    return new Future.value(val != null ? val : defaultVal);
  }

  Future<String> setValue(String key, String value) {
    _dirty = true;
    _map[key] = value;
    _controller.add(new PreferenceEvent(this, key, value));
    return new Future.value(_map[key]);
  }

  Future removeValue(List<String> keys) {
    keys.forEach((key) => _map.remove(key));
    return new Future.value();
  }

  Future clear() {
    _map.clear();
    return new Future.value();
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
class _ChromePreferenceStore implements PreferenceStore {
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
  Future<String> getValue(String key, [String defaultVal]) {
    if (_map.containsKey(key)) {
      return new Future.value(_map[key]);
    } else {
      return _storageArea.get(key).then((Map<String, String> map) {
        // TODO(ussuri): Shouldn't we cache the just read value in _map?
        final String val = map == null ? null : map[key];
        return val != null ? val : defaultVal;
      });
    }
  }

  /**
   * Removes list of items.
   */
  Future removeValue(List<String> keys) {
    return _storageArea.remove(keys).then((Map<String, String> map) {
      keys.forEach((key) => _map.remove(key));
    });
  }

  /**
   * Removes all preferences.
   */
  Future clear() {
    return _storageArea.clear().then((_) => _map.clear());
  }

  /**
   * Set the value for the given key. The returned [Future] has the same value
   * as [value] on success.
   */
  Future<String> setValue(String key, String value) {
    if (value == null) {
      return removeValue([key]);
    } else {
      _map[key] = value;
      _controller.add(new PreferenceEvent(this, key, value));

      _startTimer();

      return new Future.value(_map[key]);
    }
  }

  /**
   * Flush any unsaved changes to this [PreferenceStore].
   */
  void flush() {
    if (_map.isNotEmpty) {
      _storageArea.set(_map);
      _logger.info('saved preferences: ${_map.keys}');
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
}
