
/**
 * Methods and utilities for dealing with specific file types
 */
library spark.filetypes;

import 'dart:async';

import 'package:path/path.dart' as path;

import 'preferences.dart';
import 'workspace.dart';

final FileTypeRegistry _FILE_TYPE_REGISTRY = new FileTypeRegistry._();

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
 * A registry for all known handled file types. 
 */
class FileTypeRegistry {
  
  FileTypeRegistry._() :
    _knownTypes = new Map.fromIterable(_INBUILT_TYPES.keys, value: (k) => _INBUILT_TYPES[k].split('|'));
  
  factory FileTypeRegistry() {
    return _FILE_TYPE_REGISTRY;
  }
  
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
   * Creates a new [FileTypePreferences] object for the given file,
   * with all of the global defaults
   */
  FileTypePreferences createPreferences(String fileType) {
    if (!_knownTypes.keys.contains(fileType)) {
      throw new ArgumentError('Unknown file type: ${fileType}');
    }
    return new FileTypePreferences._(fileType);
  }
      
  
  /**
   * Returns a future the file type preferences for the given file, or the global defaults
   * if there is no stored preference value for the key. 
   */
  Future<FileTypePreferences> restorePreferences(PreferenceStore prefStore, String fileType) {
    if (!_knownTypes.keys.contains(fileType)) {
      return new Future.error(new ArgumentError('Unknown file type: $fileType'));
    }
    return prefStore.getJsonValue('fileTypePrefs/$fileType', ifAbsent: () => null)
        .then(
            (prefs) => new FileTypePreferences._(fileType, prefs: prefs));
  }
  
  /**
   * Store the preferences for the file type as a JSON encoded map under the key
   * `'fileTypePrefs/${fileType}'`
   */
  Future persistPreferences(PreferenceStore prefStore, FileTypePreferences prefs) =>
      prefStore.setJsonValue('fileTypePrefs/${prefs.fileType}', prefs._toMap());  
  
  /**
   * Forwards all [PreferenceChangeEvent] from the given [PreferenceStore]
   * into a new stream if they represent a change in the given fileType. 
   */
  Stream <FileTypePreferences> onFileTypePreferenceChange(PreferenceStore prefStore, String fileType) {
    void forwardEventData(PreferenceEvent data, EventSink<FileTypePreferences> sink) {
     if (data.key.startsWith('fileTypePrefs')) {
       String prefFileType = data.key.split('/')[1];
       if (prefFileType == fileType) {
         Map jsonVal = data.valueAsJson(ifAbsent: () => null);
         sink.add(new FileTypePreferences._(fileType, prefs: jsonVal)); 
       }
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

/**
 * A delegating preference store which handles file type errors.
 */
class FileTypePreferences {
  //By making this const, we ensure that preferences 
  //can only take primitive values, maps or lists.
  static const Map _GLOBAL_DEFAULTS = 
      const { 'useSoftTabs' : true,
              'tabSize' : 2 };
 
  final String fileType;
  
  /**
   * Should soft tabs be used in the editor?
   * If `true`, then spaces will be used instead of tab stops when editing files
   * of the specified type.
   */
  bool useSoftTabs;
  
  /**
   * The size of a tab stop in the editor.
   */
  int tabSize;
  
  /**
   * Creates a new [FileTypePreferences] object with the default values for every
   * preference
   */
  FileTypePreferences._(String this.fileType, { Map prefs: null }) {
    if (prefs == null) prefs = _GLOBAL_DEFAULTS;
    useSoftTabs = prefs['useSoftTabs'];
    tabSize = prefs['tabSize'];
  }
  
  Map _toMap() {
    Map m = new Map();
    m['useSoftTabs'] = useSoftTabs;
    m['tabSize'] = tabSize;
    return m;
  }
}