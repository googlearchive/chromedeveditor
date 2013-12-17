
/**
 * Methods and utilities for dealing with specific file types
 */
library spark.filetypes;

import 'dart:async';

import 'preferences.dart';
import 'utils.dart';
import 'workspace.dart';

/**
 * Preferences specific to a given file type
 */
abstract class FileTypePreferences {
  final String fileType;
  FileTypePreferences(String this.fileType);
  /**
   * Return a json serializable map of the preferences.
   */
  Map<String,dynamic> toMap();
}

/**
 * An interface for defining handlers of file types
 * If the argument [:prefs:] is not provided or is null, returns
 * a [FileTypePreferences] object containing default values for all
 * the stored preferences.
 */
typedef FileTypePreferences PreferenceFactory(String fileType, [Map prefs]);


/**
 * Returns a future the file type preferences for the given file, or the global defaults
 * if there is no stored preference value for the key.
 *
 * Note: [fileType] is the canonical file extension of the name.
 */
Future<FileTypePreferences> restorePreferences(PreferenceStore prefStore, PreferenceFactory prefFactory, Resource file) {
  var fileType = canonicFileExt(file.name);
  return prefStore.getJsonValue('fileTypePrefs/$fileType', ifAbsent: () => null)
      .then((prefs) {
        var defaults = prefFactory(fileType);
        if (prefs == null) return defaults;
        return prefFactory(
            fileType,
            new Map.fromIterable(defaults.toMap().keys, value: (k) => prefs[k]));
      });
}

/**
 * Store the preferences for the file type as a JSON encoded map under the key
 * `'fileTypePrefs/${fileType}'`
 */
Future persistPreferences(PreferenceStore prefStore, FileTypePreferences prefs) {
  Completer completer = new Completer<String>();
  prefStore.getJsonValue('fileTypePrefs/${prefs.fileType}')
    .then((existingPrefs) {
      var toUpdate = prefs.toMap();
      var updated;
      if (existingPrefs == null) {
        updated = toUpdate;
      } else {
        updated = new Map.fromIterable(
          existingPrefs.keys,
          value: (k) => toUpdate.containsKey(k) ? toUpdate[k] : existingPrefs[k]);
      }
      prefStore.setJsonValue('fileTypePrefs/${prefs.fileType}', updated)
          .then(completer.complete, onError: completer.completeError);
    });
  return completer.future;
}

/**
 * Forwards all [PreferenceChangeEvent] from the given [PreferenceStore]
 * into a new stream if they represent a change in the given fileType.
 */
Stream <FileTypePreferences> onFileTypePreferenceChange(PreferenceStore prefStore, PreferenceFactory prefFactory) {
  void forwardEventData(PreferenceEvent data, EventSink<FileTypePreferences> sink) {
    if (data.key.startsWith('fileTypePrefs')) {
       String fileType = data.key.split('/')[1];
       Map jsonVal = data.valueAsJson(ifAbsent: () => null);
       var defaults = prefFactory(fileType);
       var prefs;
       if (jsonVal == null) {
         prefs = defaults;
       } else {
          prefs = prefFactory(
              fileType,
              new Map.fromIterable(defaults.toMap().keys, value: (k) => jsonVal[k]));
       }
       sink.add(prefs);
    }
  }

  return new StreamTransformer<PreferenceEvent, FileTypePreferences>
      .fromHandlers(
          handleData: forwardEventData,
          handleError: (error, stackTrace, sink) => sink.addError(error, stackTrace),
          handleDone: (sink) => sink.close())
      .bind(prefStore.onPreferenceChange);
}