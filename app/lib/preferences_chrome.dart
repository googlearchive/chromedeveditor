
library spark.preferences;

import 'dart:async';

import 'package:chrome/app.dart' as chrome;

ChromePreferenceStore chromePrefsLocal = new ChromePreferenceStore(chrome.storage.local);
ChromePreferenceStore chromePrefsSync = new ChromePreferenceStore(chrome.storage.sync);

/**
 * A persistent preference mechanism.
 */
class ChromePreferenceStore {

  StreamController<PreferenceEvent> streamController =
      new StreamController<PreferenceEvent>();

  chrome.StorageArea _storageArea;

  ChromePreferenceStore(chrome.StorageArea storageArea) {
    this._storageArea = storageArea;
  }

  /**
   * Get the value for the given key. The value is returned as a [Future].
   */
  Future<String> getValue(String key){
    return _storageArea.get([key]).then((Map<String, String> map) {
      return new Future.value(map == null ? null : map[key]);
    });
  }

  /**
   * Set the value for the given key. The returned [Future] has the same value
   * as [value] on success.
   */
  Future<String> setValue(String key, String value){
    Map<String, String> map = {};
    map[key] = value;

    return _storageArea.set(map).then((chrome.StorageArea _) {
      streamController.add(new PreferenceEvent(this, key, value));
      return new Future.value(value);
    });
  }

  /**
   * Flush any unsaved changes to this [PreferenceStore].
   */
  void flush(){
    // TODO: implement this if needed or else remove
  }

  Stream<PreferenceEvent> get onPreferenceChange => streamController.stream;
}

/**
 * A event class for preference changes.
 */
class PreferenceEvent {
  final ChromePreferenceStore store;
  final String key;
  final String value;

  PreferenceEvent(this.store, this.key, this.value);
}
