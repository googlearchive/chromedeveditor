
/**
 * Methods and utilities for dealing with specific file types
 */
library spark.filetypes;

import 'dart:async';

import 'package:path/path.dart' as path;

import 'preferences.dart';
import 'workspace.dart';

/**
 * The global file type registry.
 */
final FileTypeRegistry fileTypeRegistry = new FileTypeRegistry._();

/**
 * A group of file types that we know about a priori. The runtime can 
 * extend this using [FileTypeRegistry]
 */
const Map<String, String> _INBUILT_TYPES = 
    const { 'css'  : '.css',
            'dart' : '.dart',
            'html' : '.htm|.html',
            'js'   : '.js',
            'json' : '.json',
            'md'   : '.md',
            'yaml' : '.yaml' };
        
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
 * A registry for all known handled file types. 
 */
class FileTypeRegistry {
  
  FileTypeRegistry._() :
    _knownTypes = new Map.fromIterable(_INBUILT_TYPES.keys, value: (k) => _INBUILT_TYPES[k].split('|'));
  
  final Map<String, List<String>> _knownTypes;
  
  /**
   * Register a custom type.
   * [:extensions:] is a pipe (`'|'`) seperated list of all extensions
   * associated with the type.
   * Returns the type registered with at least one of the extensions
   * in [:extensions:] after the registration (which will be equal to
   * type if the registration was successful).
   */
  String registerCustomType(String type, String extensions) {
    var exts = extensions.split('|');
    for (var k in _knownTypes.keys) {
      if (_knownTypes[k].any(exts.contains)) {
        return k;
      }
    }
    _knownTypes[type] = exts;
    return type;
  }
      
  
  /**
   * Retieves the file type associated with the given file.
   */
  String fileTypeOf(Resource file) =>
    _knownTypes.keys.firstWhere(
          (k) => _knownTypes[k].contains(path.extension(file.path)), 
          orElse: () => "unknown");
      
  
  /**
   * Returns a future the file type preferences for the given file, or the global defaults
   * if there is no stored preference value for the key. 
   */
  Future<FileTypePreferences> restorePreferences(PreferenceStore prefStore, PreferenceFactory prefFactory, String fileType) {
    if (!_knownTypes.keys.contains(fileType)) {
      return new Future.error(new ArgumentError('Unknown file type: $fileType'));
    }
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
}