// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:ini/ini.dart' as ini;

import 'workspace.dart' as workspace;
import 'exception.dart';

/**
 * Defines class for finding and understanding .editorConfig options file for a
 * given source.  For more information: http://editorconfig.org/
 */
class EditorConfig {
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
  Future whenReady;

  EditorConfig(workspace.File file) {
    ConfigSectionMatcher matcher = new ConfigSectionMatcher(file);
    whenReady = matcher.getSections().then((_) {
      // indent_style
      useSpaces = _propertyToBool(matcher, "indent_style", trueValue: "space",
          falseValue: "tab");

      // tab_width
      String value = matcher.getValue("tab_width");
      if (value == null) {
        matcher.getValue("indent_size");
      }

      tabWidth = int.parse(value);
      if (tabWidth.toString() != value || tabWidth < 1) {
        throw new EditorConfigException.forProperty("tab_width", value);
      }

      // indent_size
      value = matcher.getValue("indent_size");
      if (value == "tab") {
        indentSize = tabWidth;
      } else {
        indentSize = int.parse(value);
        if (indentSize.toString() != value || indentSize < 1) {
          throw new EditorConfigException.forProperty("indent_size", value);
        }
      }

      // end_of_line
      value = matcher.getValue("end_of_line");
      if (value == "cr") {
        lineEnding = ENDING_CR;
      } else if (value == "lf") {
        lineEnding = ENDING_LF;
      } else if (value == "crlf") {
        lineEnding = ENDING_CRLF;
      } else {
        throw new EditorConfigException.forProperty("end_of_line", value);
      }

      // charset
      value = matcher.getValue("charset");
      if (value == "latin1") {
        charSet = CHARSET_LATIN;
      } else if (value == "utf-8") {
        charSet = CHARSET_UTF8;
      } else if (value == "utf-8-bom") {
        charSet = CHARSET_UTF8BOM;
      } else if (value == "utf-16be") {
        charSet = CHARSET_UTF16BE;
      } else if (value == "utf-16le") {
        charSet = CHARSET_UTF16LE;
      } else {
        throw new EditorConfigException.forProperty("charset", value);
      }

      // trim_trailing_whitespace
      trimWhitespace = _propertyToBool(matcher, "trim_trailing_whitespace");

      // insert_final_newline
      insertFinalNewline = _propertyToBool(matcher, "insert_final_newline");
    });
  }

  bool _propertyToBool(ConfigSectionMatcher matcher, String propertyName,
      {String trueValue: "true", String falseValue: "false"}) {
    String value = matcher.getValue(propertyName);

    if (value == trueValue) {
      return true;
    } else if (value == falseValue) {
      return false;
    }

    throw new EditorConfigException.forProperty(propertyName, value);

    // To keep analyzer happy
    return false;
  }
}

class EditorConfigException extends SparkException {
  EditorConfigException.forProperty(String key, String value) : super(
      (value == null) ? "Missing value for $key" : "Invalid value for $key: $value") {
  }
}

class ConfigSectionMatcher {
  List<ConfigSection> configSections = [];
  workspace.File file;
  chrome.ChromeFileEntry get fileEntry => file.entry;

  ConfigSectionMatcher(this.file);

  Future<ConfigFile> getSections() {
    return fileEntry.getParent().then((chrome.DirectoryEntry dir) {
      return getSectionsForPath(dir);
    });
  }

  Future<ConfigFile> getSectionsForPath(chrome.DirectoryEntry dir) {
    int insertIndex = configSections.length;
    return dir.getFile(".editorConfig").then((chrome.ChromeFileEntry configFile) {
      return configFile.readText();
    }).catchError((e) {
      if (e is String && e == "file doesn't exist") {
        return "";
      } else if (e.name == "NotFoundError") {
        return "";
      }

      return e;
    }).then((String configContent) {
      new ConfigFile(configContent).sections.forEach(
          (ConfigSection section) {
        var fullPath = fileEntry.fullPath;
        if (section.matchesPath(fullPath)) {
          configSections.insert(insertIndex, section);
        }
      });

      if (file.project.entry.fullPath != dir.fullPath) {
        return dir.getParent();
      }
    }).then((chrome.DirectoryEntry parent) {
      if (parent != null) {
        return getSectionsForPath(parent);
      }
    });
  }

  String getValue(String propertyName) {
    String value;
    for (ConfigSection configSection in configSections) {
      value = configSection.getValue(propertyName);
      if (value != null) {
        return value;
      }
    }
    return null;
  }
}

/**
 * Defines a "ConfigFile" which is an .ini format file with globs for the
 * section headers (to match files) and options relating to those file matches
 * under the headers.
 */
class ConfigFile {
  ini.Config _iniConfig;
  bool get root => _iniConfig.get("default", "root") == "true";
  List<ConfigSection> sections = [];

  ConfigFile(String content) {
    parseConfig(content);
  }

  void parseConfig(String content) {
    _iniConfig = ini.Config.fromStrings(content.split("\n"));
    _iniConfig.sections().forEach((String sectionId) {
      ConfigSection section = new ConfigSection(_iniConfig, sectionId);
      sections.add(section);
    });
  }
}

class ConfigSection {
  ini.Config _config;

  String sectionId;
  Glob glob;

  ConfigSection(this._config, this.sectionId) {
    glob = new Glob(sectionId);
  }

  bool matchesPath(String path) {
    return (glob.matchPath(path) == Glob.COMPLETE_MATCH);
  }

  String getValue(String propertyName) {
    var value = _config.get(sectionId, propertyName);
    return (value != null) ? value.toLowerCase() : null;
  }
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

class PartialPathMatcher extends GlobMatcher {
  int get end => tokenStart;
  String toRegExp() => "^(.*/|)";

  PartialPathMatcher(String input, GlobPattern pattern, int location) :
      super(input, pattern, location, location);
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
    bool matchFull = pattern.substring(0,1) == "/";
    GlobPattern globPattern = new GlobPattern();

    if (matchFull) pattern = pattern.substring(1);

    List<GlobMatcher> globMatchers = globPattern.allMatches(pattern).toList();

    if (!matchFull) {
      globMatchers.insert(0, new PartialPathMatcher(pattern, globPattern, 0));
    }

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
