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

abstract class OutlineTopLevelEntry {
  String name;

  OutlineTopLevelEntry();

  factory OutlineTopLevelEntry.fromMap(Map mapData) {
    String type = mapData["type"];
    OutlineTopLevelEntry entry;

    if (type == OutlineClass._type) {
      entry = new OutlineClass.fromMap(mapData);
    } else if (type == TopLevelFunction._type) {
      entry = new TopLevelFunction.fromMap(mapData);
    }

    entry.name = mapData["name"];
    return entry;
  }

  Map toMap() {
    return {
      "name": name,
    };
  }
}

class OutlineClass extends OutlineTopLevelEntry {
  static String _type = "class";

  bool abstract = false;

  OutlineClass.fromMap(Map mapData) {
    abstract = mapData["abstract"];
  }

  Map toMap() {
    return super.toMap()..addAll({
      "type": _type,
      "abstract": abstract,
    });
  }
}

class TopLevelFunction extends OutlineTopLevelEntry {
  static String _type = "function";

  TopLevelFunction.fromMap(Map mapData);

  Map toMap() {
    return super.toMap()..addAll({
      "type": _type
    });
  }
}


