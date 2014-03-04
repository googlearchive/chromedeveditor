// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

abstract class Serializable {
  // TODO(ericarnold): Implement as, and refactor any classes containing toMap
  // to implement Serializable:
  // Map toMap();
  // void populateFromMap(Map mapData);
}

class AnalysisError {
  String message;
  int offset;
  int lineNumber;
  int errorSeverity;
  int length;

  AnalysisError();

  AnalysisError.fromMap(Map mapData) {
    message = mapData["message"];
    offset = mapData["offset"];
    lineNumber = mapData["lineNumber"];
    errorSeverity = mapData["errorSeverity"];
    length = mapData["length"];
  }

  Map toMap() {
    return {
        "message": message,
        "offset": offset,
        "lineNumber": lineNumber,
        "errorSeverity": errorSeverity,
        "length": length
    };
  }
}

class ErrorSeverity {
  static int NONE = 0;
  static int ERROR = 1;
  static int WARNING = 2;
  static int INFO = 3;
}

/**
 * Defines an outline containing instances of [OutlineTopLevelEntry].
 */
class Outline {
  List<OutlineTopLevelEntry> entries = [];

  Outline.fromMap(Map mapData) {
    entries = mapData['entries'].map((Map serializedEntry) =>
      new OutlineTopLevelEntry.fromMap(serializedEntry)).toList();
  }
}

/**
 * Defines any line-item entry in the [Outline].
 */
abstract class OutlineEntry {
  String name;
  int startOffset;
  int endOffset;

  void populateFromMap(Map mapData) {
    name = mapData["name"];
    startOffset = mapData["startOffset"];
    endOffset = mapData["endOffset"];
  }

  Map toMap() {
    return {
      "name": name,
      "startOffset": startOffset,
      "endOffset": endOffset,
    };
  }
}

/**
 * Defines any top-level entry in the [Outline].
 */
abstract class OutlineTopLevelEntry extends OutlineEntry {
  OutlineTopLevelEntry();

  factory OutlineTopLevelEntry.fromMap(Map mapData) {
    String type = mapData["type"];
    OutlineTopLevelEntry entry;

    if (type == OutlineClass._type) {
      entry = new OutlineClass()..populateFromMap(mapData);
    } else if (type == OutlineTopLevelFunction._type) {
      entry = new OutlineTopLevelFunction()..populateFromMap(mapData);
    } else if (type == OutlineTopLevelVariable._type) {
      entry = new OutlineTopLevelVariable()..populateFromMap(mapData);
    }

    entry.populateFromMap(mapData);
    return entry;
  }

  Map toMap() => super.toMap();
}

/**
 * Defines a class entry in the [Outline].
 */
class OutlineClass extends OutlineTopLevelEntry {
  static String _type = "class";

  bool abstract = false;
  List<OutlineMember> members = [];

  void populateFromMap(Map mapData) {
    super.populateFromMap(mapData);
    abstract = mapData["abstract"];
    members = mapData["members"].map((Map memberMap) =>
        new OutlineMember.fromMap(memberMap)).toList();
  }

  Map toMap() {
    return super.toMap()..addAll({
      "type": _type,
      "abstract": abstract,
      "members": members.map((OutlineMember element) => element.toMap())
    });
  }
}

/**
 * Defines any member entry in an [OutlineClass].
 */
abstract class OutlineMember extends OutlineEntry {
  bool static;

  OutlineMember();

  factory OutlineMember.fromMap(Map mapData) {
    String type = mapData["type"];
    OutlineMember entry;

    if (type == OutlineMethod._type) {
      entry = new OutlineMethod()..populateFromMap(mapData);
    } else if (type == OutlineClassVariable._type) {
      entry = new OutlineClassVariable()..populateFromMap(mapData);
    }

    entry.static = mapData["static"];

    return entry;
  }
}

/**
 * Defines a method entry in an [OutlineClass].
 */
class OutlineMethod extends OutlineMember {
  static String _type = "method";

  bool static = false;

  Map toMap() {
    return super.toMap()..addAll({
      "type": _type,
    });
  }
}

/**
 * Defines a class variable entry in an [OutlineClass].
 */
class OutlineClassVariable extends OutlineMember {
  static String _type = "class-variable";

  bool static = false;

  Map toMap() {
    return super.toMap()..addAll({
      "type": _type,
    });
  }
}

/**
 * Defines a top-level function entry in the [Outline].
 */
class OutlineTopLevelFunction extends OutlineTopLevelEntry {
  static String _type = "function";

  Map toMap() {
    return super.toMap()..addAll({
      "type": _type
    });
  }
}

/**
 * Defines a top-level variable entry in the [Outline].
 */
class OutlineTopLevelVariable extends OutlineTopLevelEntry {
  static String _type = "top-level-variable";

  Map toMap() {
    return super.toMap()..addAll({
      "type": _type
    });
  }
}



