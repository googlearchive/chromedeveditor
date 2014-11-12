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
import 'dart:convert';
import 'dart:html';

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:ini/ini.dart' as ini;

/**
 * A PreferenceStore backed by `chome.storage.local`.
 */
PreferenceStore localStore = new _ChromePreferenceStore(
    chrome.storage.local, 'local', new Duration(milliseconds: 100));

/**
 * A PreferenceStore backed by `chome.storage.sync`.
 */
PreferenceStore syncStore = new _ChromePreferenceStore(
    chrome.storage.sync, 'sync', new Duration(milliseconds: 100));

/**
 * Preferences specific to Spark.
 */
class SparkPreferences {
  final PreferenceStore prefsStore;

  Future onPreferencesReady;
  JsonPreferencesStore _jsonStore;

  // [JsonPreference] subclass instance for each preference:
  JsonPreference<bool> stripWhitespaceOnSave;
  JsonPreference<String> editorTheme;
  JsonPreference<num> editorFontSize;
  JsonPreference<String> keyBindings;

  JsonPreference<IndentationPreference> indentation;

  SparkPreferences(this.prefsStore) {
    _jsonStore = new JsonPreferencesStore(prefsStore);
    // Initialize each preference:
    stripWhitespaceOnSave = new JsonPreference<bool>(_jsonStore,
        "stripWhitespaceOnSave");
    editorTheme = new JsonPreference<String>(_jsonStore, "editorTheme");
    editorFontSize = new JsonPreference<num>(_jsonStore, "editorFontSize");
    keyBindings = new JsonPreference<String>(_jsonStore, "keyBindings");

    onPreferencesReady = _jsonStore.whenLoaded;
  }
}

class IndentationPreferences {
  Map<String, IndentationPreference> preferences;

  String toJson() => preferences.keys.fold("", (String prev, String key) =>
      JSON.encode({prev:preferences[key].toJson()}));
}

class IndentationPreference {
  bool useTabs;
  int width;

  IndentationPreferences() {}

  String toJson() => JSON.encode({"useTabs":useTabs, "width":width});
}

class JsonPreferencesStore {
  Map _defaultMap;
  Map _userMap;

  PreferenceStore _persistentStore;
  Future whenLoaded;
  bool _loaded = false;

  // TODO: implement isDirty
  bool get isDirty => null;

  Stream<PreferenceEvent> get onPreferenceChange => _changeConroller.stream;
  StreamController<PreferenceEvent> _changeConroller = new StreamController();

  JsonPreferencesStore(this._persistentStore) {
    whenLoaded = Future.wait([_loadDefaultPrefs(), _loadUserPrefs()]).then((_) =>
        _loaded = true);
  }

  Future _loadDefaultPrefs() {
    return HttpRequest.getString(chrome.runtime.getURL('prefs.json'))
        .then((String json) => _defaultMap = JSON.decode(json));
  }

  Future _loadUserPrefs() {
    return _persistentStore.getValue("userJsonPrefs", "{}")
        .then((String json) {
      _userMap = JSON.decode(json);
    });
  }

  dynamic getValue(String id, [dynamic defaultValue]) {
    if (!_loaded) throw "JSON preferences are not finished loading";
    return _userMap.containsKey(id) ? _userMap[id] : _defaultMap[id];
  }

  Future setValue(String id, dynamic value) {
    _userMap[id] = value;
    _changeConroller.add(new PreferenceEvent(_persistentStore, id, value.toString()));
    String jsonString = JSON.encode(_userMap);
    return _persistentStore.setValue("userJsonPrefs", jsonString);
  }

  Future removeValue(List<String> keys) {
    keys.forEach((String key) => _userMap.remove(key));
    return new Future.value();
  }
}

/**
 * Defines a preference with built in `whenLoaded` [Future] and easy access to
 * getting and setting (automatically saving as well as caching) the preference
 * `value`.
 */
class JsonPreference<T> {
  final String _id;
  final JsonPreferencesStore _store;

  final StreamController<T> _changedController = new StreamController.broadcast();
  Stream get onChanged => _changedController.stream;

  /**
   * [_prefsMap] is the Map of prefrence values to use and [_id] is the id of
   * the stored preference.
   */
  JsonPreference(this._store, this._id);

  T get value => _store.getValue(_id);

  void set value(T newValue) {
    _store.setValue(_id, newValue);
    _changedController.add(newValue);
  }
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
  Future<dynamic> getValue(String key, [dynamic defaultVal]);

  /**
   * Set the value for the given key. The returned [Future] has the same value
   * as [value] on success.
   */
  Future setValue(String key, dynamic value);

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

  Future getValue(String key, [dynamic defaultVal]) {
    final val = _map[key];
    return new Future.value(val != null ? val : defaultVal);
  }

  Future setValue(String key, dynamic value) {
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
  Future<dynamic> getValue(String key, [var defaultVal]) {
    if (_map.containsKey(key)) {
      return new Future.value(_map[key]);
    } else {
      return _storageArea.get(key).then((Map map) {
        final val = map == null ? null : map[key];
        return val != null ? val : defaultVal;
      });
    }
  }

  /**
   * Removes list of items.
   */
  Future removeValue(List<String> keys) {
    // Using a completer ensures the correct updating order: source of truth
    // (_storageArea) first, cache (_map) second.
    var completer = new Completer();
    _storageArea.remove(keys).then((Map map) {
      keys.forEach((key) => _map.remove(key));
      completer.complete();
    });
    return completer.future;
  }

  /**
   * Removes all preferences.
   */
  Future clear() {
    // See comment in [removeValue].
    var completer = new Completer();
    _storageArea.clear().then((_) {
      _map.clear();
      completer.complete();
    });
    return completer.future;
  }

  /**
   * Set the value for the given key. The returned [Future] has the same value
   * as [value] on success.
   */
  Future<String> setValue(String key, var value) {
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
  final dynamic value;

  PreferenceEvent(this.store, this.key, this.value);
}

abstract class GlobMatcher extends Match {
  String operator [](int group) => this.group(group);

  final int start;
  final int tokenStart;
  int get end;
  final String input;
  final GlobPattern pattern;
  final int groupCount = 1;

  GlobMatcher(this.input, this.pattern, this.start, this.tokenStart);

  String group(int group) {
    if (group != 0) throw new RangeError("GlobMatchers only have one group");
    return input.substring(start, end);
  }

  @override
  List<String> groups(List<int> groupIndices) {
    if (groupIndices.length > 1) {
      throw new RangeError("GlobMatchers only have one group");
    }
    return [this.group(groupIndices[0])];
  }

  String toRegExp();
}

class StaticMatcher extends GlobMatcher {
  int get end => tokenStart;
  String toRegExp() => "";

  StaticMatcher(String input, GlobPattern pattern, int start, int end) :
      super(input, pattern, start, end);
}

class FileWildcardMatcher extends GlobMatcher {
  int get end => tokenStart + 1;
  String toRegExp() => "[^/]*";

  FileWildcardMatcher(String input, GlobPattern pattern, int start, int tokenStart) :
      super(input, pattern, start, tokenStart);
}

class PathWildcardMatcher extends GlobMatcher {
  int get end => tokenStart + 2;
  String toRegExp() => ".*";

  PathWildcardMatcher(String input, GlobPattern pattern, int start, int tokenStart) :
      super(input, pattern, start, tokenStart);
}

class SingleCharMatcher  extends GlobMatcher {
  int get end => tokenStart + 1;
  String toRegExp() => "[^/]";

  SingleCharMatcher(String input, GlobPattern pattern, int start, int tokenStart) :
      super(input, pattern, start, tokenStart);
}

class CharRangeMatcher extends GlobMatcher {
  int _end = null;
  int get end => (_end == null) ? _end = input.indexOf("]", tokenStart) : _end;
  String toRegExp() => "[" + (negate ? "^" : "") + "$rangeString]";
  bool get negate => input[tokenStart + 1] == "!";
  String get rangeString => input.substring(tokenStart + (negate ? 1 : 2), end - 1);

  CharRangeMatcher(String input, GlobPattern pattern, int start, int tokenStart) :
      super(input, pattern, start, tokenStart);
}

class IdentifierListMatcher extends GlobMatcher {
  int _end = null;
  int get end => (_end == null) ? _end = input.indexOf("}", tokenStart) : _end;
  String toRegExp() => "(" + identifiers.join('|') + ")";
  String get _matcherContent => input.substring(tokenStart + 1, end - 1);
  List<String> get identifiers => _matcherContent.split(new RegExp(r",\s*"));

  IdentifierListMatcher(String input, GlobPattern pattern, int start, int tokenStart) :
      super(input, pattern, start, tokenStart);
}

class GlobPattern implements Pattern {
  Iterable<Match> allMatches(String string, [int start = 0]) {
    List<Match> matches = [];

    do {
      GlobMatcher match = matchAsPrefix(string, start);
      if (match == null) {
        break;
      }
      matches.add(match);
      start = match.end + 1;
    } while(start < string.length);

    return matches;
  }

  GlobMatcher matchAsPrefix(String string, [int start = 0]) {
    int n = start;
    do {
      n = string.indexOf(new RegExp(r"[\\*?\[\{]"), n);
      GlobMatcher matcher;

      if (n == -1) {
        return new StaticMatcher(string, this, start, string.length);
      }

      // Identifies the first char as escape and ignores the second)
      switch(string[n]) {
        case "\\":
          // Ignore next char after escape
          n = n + 2;
          continue;
        case "*":
          if (string.length > n + 1 && string[n + 1] == "*") {
            return new PathWildcardMatcher(string, this, start, n);
          } else {
            return new FileWildcardMatcher(string, this, start, n);
          }
          break;
        case "?":
          return new SingleCharMatcher(string, this, start, n);
        case "[":
          return new SingleCharMatcher(string, this, start, n);
        case "{":
          return new IdentifierListMatcher(string, this, start, n);
      }
    } while(n < string.length);

    throw "Unexpected end of line";
  }
}

/**
 * Defines a matcher for recursively matching of globs.
 */
class Glob {
  static int NO_MATCH = 0;
  static int PREFIX_MATCH = 1;
  static int COMPLETE_MATCH = 2;
  static final RegExp _escapePattern = new RegExp("[!@#\$%^&()-.,<>+=\\/~`|]");

  List<String> _globRegExpParts;

  Glob(String pattern) {
    Iterable<Match> globMatchers = new GlobPattern().allMatches(pattern);
    _globRegExpParts = globMatchers.map((GlobMatcher m) =>
        _escape(pattern.substring(m.start, m.tokenStart)) + m.toRegExp()).toList();
  }

  String _escape(String toEscape) {
    int start = 0;
    return _escapePattern.allMatches(toEscape).fold("", (String s, Match m) =>
        s + toEscape.substring(start, (start = m.end) - 1) + "\\" + m[0]) +
        toEscape.substring(start);
  }

  // Matches a path to the glob pattern.  Returns one of three values:
  //
  // NO_MATCH - No match found ("foo" won't match "bar")
  // PREFIX_MATCH - Prefix match found ("f*/b*/" partially matches "foo/")
  // COMPLETE_MATCH - Prefix match found ("f**/b*" completely matches "foo/bar/baz")
  int matchPath(String path) {
    int lastIndex = 0;

    String globSoFar = "";
    int globIndex = 0;

    for (;globIndex < _globRegExpParts.length; globIndex++) {
      String globPart = _globRegExpParts[globIndex];
      globSoFar += ((globSoFar != "") ? ".*" : "") +
          globPart.replaceAll("*", "[^/]*").replaceAll("?", "[^/]");
      if (globIndex == _globRegExpParts.length - 1) globSoFar = globSoFar + "\$";
      if (new RegExp(globSoFar).matchAsPrefix(path) == null) break;
    }

    if (globIndex > 0) {
      if (globIndex == _globRegExpParts.length) {
        return COMPLETE_MATCH;
      }
      return PREFIX_MATCH;
    }
    return NO_MATCH;
  }
}

class EditorConfig {
  ini.Config _iniConfig;
  bool get root => _iniConfig.get("default", "root") == "true";
  Map<String, EditorConfigSection> sections = {};

  EditorConfig.fromString(String content) {
    _iniConfig = ini.Config.fromStrings(content.split("\n"));
    _iniConfig.sections().forEach((String id) =>
        sections[id] = new EditorConfigSection(_iniConfig, id));
  }
}

class EditorConfigSection {
  static final int ENDING_CR = 1;
  static final int ENDING_LF = 2;
  static final int ENDING_CRLF = 3;

  static final int CHARSET_LATIN = 1;
  static final int CHARSET_UTF8 = 2;
  static final int CHARSET_UTF8BOM = 3;
  static final int CHARSET_UTF16BE = 4;
  static final int CHARSET_UTF16LE = 5;

  bool useSpaces;
  int indentSize;
  int tabWidth;
  int lineEnding;
  int charSet;
  bool trimWhitespace;
  bool insertFinalNewline;

  _EditorConfigProperties _properties;

  EditorConfigSection(ini.Config _config, String id) {
    _properties = new _EditorConfigProperties(_config, id);
    _validateAndInit(id);
  }

  _validateAndInit(String id) {
    // indent_style
    switch (_properties.indentStyle) {
      case "space":
        useSpaces = true;
        break;
      case "tab":
        useSpaces = false;
        break;
      default:
        _throwExceptionFor("indent_style");
    }

    // tab_width
    String tabWidthProp = _properties.tabWidth;
    tabWidth = int.parse(tabWidthProp);
    if (tabWidth.toString() != tabWidthProp || tabWidth < 1) {
      _throwExceptionFor("tab_width");
    }

    // indent_size
    String indentSizeProp = _properties.indentSize;
    if (indentSizeProp == "tab") {
      indentSize = tabWidth;
    } else {
      indentSize = int.parse(indentSizeProp);
      if (indentSize.toString() != indentSizeProp || indentSize < 1) {
        _throwExceptionFor("indent_size");
      }
    }

    // end_of_line
    String endOfLineProp = _properties.endOfLine;
    if (endOfLineProp == "cr") {
      lineEnding = ENDING_CR;
    } else if (endOfLineProp == "lf") {
      lineEnding = ENDING_LF;
    } else if (endOfLineProp == "crlf") {
      lineEnding = ENDING_CRLF;
    } else {
      _throwExceptionFor("end_of_line");
    }

    // charset
    String charSetProp = _properties.charSet;
    if (charSetProp == "latin1") {
      charSet = CHARSET_LATIN;
    } else if (charSetProp == "utf-8") {
      charSet = CHARSET_UTF8;
    } else if (charSetProp == "utf-8-bom") {
      charSet = CHARSET_UTF8BOM;
    } else if (charSetProp == "utf-16be") {
      charSet = CHARSET_UTF16BE;
    } else if (charSetProp == "utf-16le") {
      charSet = CHARSET_UTF16LE;
    } else {
      _throwExceptionFor("charset");
    }

    // trim_trailing_whitespace
    switch (_properties.trimWhitespace) {
      case "true":
        trimWhitespace = true;
        break;
      case "false":
        trimWhitespace = false;
        break;
      default:
        _throwExceptionFor("trim_trailing_whitespace");
    }

    // insert_final_newline
    switch (_properties.insertFinalNewline) {
      case "true":
        insertFinalNewline = true;
        break;
      case "false":
        insertFinalNewline = false;
        break;
      default:
        _throwExceptionFor("insert_final_newline");
    }
  }

  void _throwExceptionFor(String key) {
    throw "Invalid $key for ${_properties.id}";
  }
}

class _EditorConfigProperties {
  ini.Config _config;

  String id;

  String indentStyle;
  String indentSize;
  String tabWidth;
  String endOfLine;
  String charSet;
  String trimWhitespace;
  String insertFinalNewline;

  _EditorConfigProperties(this._config, this.id) {
    indentStyle = _takeValue("indent_style", "space");
    String indentSizeProp = _getValue("indent_size", null);
    indentSize = _takeValue("indent_size", "2");

    String value = _takeValue("tab_width", null);
    if (value != null) {
      tabWidth = value;
    } else if (indentSizeProp == "tab") {
      // Default if no tab size is specified and "tab" is used for indent_size.
      tabWidth = "2";
    } else tabWidth = indentSize;

    endOfLine = _takeValue("end_of_line", "cr");
    charSet = _takeValue("charset", "utf-8");
    trimWhitespace = _takeValue("trim_trailing_whitespace", "true");
    insertFinalNewline = _takeValue("insert_final_newline", "true");

    List<String> currentOptions = _config.options(id).toList();

    if (currentOptions.length > 0) {
      String errorKeys = currentOptions.join(", ");
      throw "Invalid options in $id: $errorKeys";
    }
  }

  String _getValue(String propertyName, dynamic defaultValue) {
    String value = _config.get(id, propertyName);
    return (value == null) ? defaultValue : value.toLowerCase();
  }

  String _takeValue(String propertyName, dynamic defaultValue) {
    String value = _getValue(propertyName, defaultValue);
    _config.remove_option(id, propertyName);
    return value;
  }
}
