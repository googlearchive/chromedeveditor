// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

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
 *
 */
class Outline {
  List<OutlineTopLevelEntry> entries = [];

  Outline.fromMap(Map mapData) {
    List<Map> serializedEntries = mapData['entries'];
    for (Map serializedEntry in serializedEntries) {
      OutlineTopLevelEntry entry = new OutlineTopLevelEntry.fromMap(serializedEntry);
      entries.add(entry);
    }
  }
}

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

class OutlineClass extends OutlineTopLevelEntry {
  static String _type = "class";

  bool abstract = false;
  List<OutlineMember> members = [];

  void populateFromMap(Map mapData) {
    super.populateFromMap(mapData);
    abstract = mapData["abstract"];
    List<Map> membersMaps = mapData["members"];
    if (membersMaps != null && membersMaps.length > 0) {
      members = membersMaps.map((Map memberMap) =>
        new OutlineMember.fromMap(memberMap)).toList();
    }
  }

  Map toMap() {
    return super.toMap()..addAll({
      "type": _type,
      "abstract": abstract,
      "members": members.map((OutlineMember element) => element.toMap())
    });
  }
}

class OutlineMember extends OutlineEntry {
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

class OutlineMethod extends OutlineMember {
  static String _type = "method";

  bool static = false;

  Map toMap() {
    return super.toMap()..addAll({
      "type": _type,
    });
  }
}

class OutlineClassVariable extends OutlineMember {
  static String _type = "class-variable";

  bool static = false;

  Map toMap() {
    return super.toMap()..addAll({
      "type": _type,
    });
  }
}

class OutlineTopLevelFunction extends OutlineTopLevelEntry {
  static String _type = "function";

  Map toMap() {
    return super.toMap()..addAll({
      "type": _type
    });
  }
}

class OutlineTopLevelVariable extends OutlineTopLevelEntry {
  static String _type = "top-level-variable";

  Map toMap() {
    return super.toMap()..addAll({
      "type": _type
    });
  }
}



