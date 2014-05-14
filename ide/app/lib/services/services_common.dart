// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.services_common;

import 'dart:async';

import '../workspace.dart';
import '../package_mgmt/package_manager.dart';
import '../package_mgmt/pub.dart';
import '../package_mgmt/pub_properties.dart';

abstract class Serializable {
  // TODO(ericarnold): Implement as, and refactor any classes containing toMap
  // to implement Serializable:
  // Map toMap();
  // void populateFromMap(Map mapData);
}

/**
 * Defines a received action event.
 */
class ServiceActionEvent {
  final String serviceId;
  final String actionId;

  bool response = false;
  bool error = false;
  Map data;

  String _callId;
  String get callId => _callId;

  ServiceActionEvent(this.serviceId, this.actionId, this.data);

  ServiceActionEvent.fromMap(Map map) :
      serviceId = map["serviceId"], actionId = map["actionId"] {
    _callId = map["callId"];
    data = map["data"];
    response = map["response"];
    error = map["error"];
  }

  ServiceActionEvent.asResponse(
      this.serviceId, this.actionId, this._callId, this.data) : response = true;

  Map toMap() {
    return {
      "serviceId": serviceId,
      "actionId": actionId,
      "callId": callId,
      // TODO(ericarnold): We can probably subclass SAE into Response specific.
      "response": response == true,
      "error": error == true,
      "data": data
    };
  }

  ServiceActionEvent createReponse([Map data = const {}]) {
    return new ServiceActionEvent.asResponse(serviceId, actionId, callId, data);
  }

  ServiceActionEvent createErrorReponse(String errorMessage) {
    return createReponse({'message': errorMessage})..error = true;
  }

  String getErrorMessage() => data['message'];

  void makeRespondable(String callId) {
    if (this._callId == null) {
      this._callId = callId;
    } else {
      throw "ServiceActionEvent is already respondable";
    }
  }

  /**
   * If this event represents an error, a [ServiceException] is thrown.
   */
  void throwIfError() {
    if (error) {
      throw new ServiceException(data['message'], serviceId, actionId);
    }
  }
}

class ServiceException {
  final String message;
  final String serviceId;
  final String actionId;

  ServiceException(this.message, [this.serviceId, this.actionId]);

  String toString() => 'ServiceException: ${message}';
}

class AnalysisError {
  String message;
  int offset;
  int lineNumber;
  int length;
  // see [ErrorSeverity]
  int errorSeverity;

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

  String toString() => '[${errorSeverity}] ${message}, line ${lineNumber}';
}

class AnalysisResult {
  Map<File, List<AnalysisError>> _results = {};

  AnalysisResult();

  AnalysisResult.fromMap(Workspace workspace, Map m) {
    Map<String, List<Map>> uuidToErrors = m;

    for (String uuid in uuidToErrors.keys) {
      List<AnalysisError> errors = uuidToErrors[uuid].map(
          (Map errorData) => new AnalysisError.fromMap(errorData)).toList();
      _results[workspace.restoreResource(uuid)] = errors;
    }
  }

  List<File> getFiles() => _results.keys.toList();

  List<AnalysisError> getErrorsFor(File file) => _results[file];
}

abstract class ContentsProvider {
  Future<String> getFileContents(String uuid);
  Future<String> getPackageContents(String relativeUuid, String packageRef);
}

class ErrorSeverity {
  static int NONE = 0;
  static int ERROR = 1;
  static int WARNING = 2;
  static int INFO = 3;
}

/**
 * Defines an object containing information about a declaration.
 */
class Declaration {
  final String name;
  final String fileUuid;
  final int offset;
  final int length;

  Declaration(this.name, this.fileUuid, this.offset, this.length);

  factory Declaration.fromMap(Map map) {
    if (map == null || map.isEmpty) return null;

    return new Declaration(map["name"], map["fileUuid"],
        map["offset"], map["length"]);
  }

  /**
   * Returns the file pointed to by the [fileUuid]. This can return `null` if
   * we're not able to resolve the file reference.
   */
  File getFile(Project project) {
    if (fileUuid == null) return null;

    if (pubProperties.isPackageRef(fileUuid)) {
      PubManager pubManager = new PubManager(project.workspace);
      PackageResolver resolver = pubManager.getResolverFor(project);
      return resolver.resolveRefToFile(fileUuid);
    } else {
      return project.workspace.restoreResource(fileUuid);
    }
  }

  Map toMap() {
    return {
      "name": name,
      "fileUuid": fileUuid,
      "offset": offset,
      "length": length,
    };
  }

  String toString() => '${fileUuid} [${offset}:${length}]';
}

/**
 * Defines an outline containing instances of [OutlineTopLevelEntry].
 */
class Outline {
  List<OutlineTopLevelEntry> entries = [];

  Outline();

  Outline.fromMap(Map mapData) {
    entries = mapData['entries'].map((Map serializedEntry) =>
        new OutlineTopLevelEntry.fromMap(serializedEntry)).toList();
  }

  Map toMap() {
    return {
      "entries": entries.map((OutlineTopLevelEntry entry) =>
          entry.toMap()).toList()
    };
  }
}

/**
 * Defines any line-item entry in the [Outline].
 */
abstract class OutlineEntry {
  String name;
  int nameStartOffset;
  int nameEndOffset;
  int bodyStartOffset;
  int bodyEndOffset;

  OutlineEntry([this.name]);

  /**
   * Populates values and children from a map
   */
  void populateFromMap(Map mapData) {
    name = mapData["name"];
    nameStartOffset = mapData["nameStartOffset"];
    nameEndOffset = mapData["nameEndOffset"];
    bodyStartOffset = mapData["bodyStartOffset"];
    bodyEndOffset = mapData["bodyEndOffset"];
  }

  Map toMap() {
    return {
      "name": name,
      "nameStartOffset": nameStartOffset,
      "nameEndOffset": nameEndOffset,
      "bodyStartOffset": bodyStartOffset,
      "bodyEndOffset": bodyEndOffset,
    };
  }
}

/**
 * Defines any top-level entry in the [Outline].
 */
abstract class OutlineTopLevelEntry extends OutlineEntry {
  OutlineTopLevelEntry([String name]) : super(name);

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

  OutlineClass([String name]) : super(name);

  /**
   * Populates values and children from a map
   */
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
      "members": members.map((OutlineMember element) =>
          element.toMap()).toList()
    });
  }
}

/**
 * Defines any member entry in an [OutlineClass].
 */
abstract class OutlineMember extends OutlineEntry {
  bool static;

  OutlineMember([String name]) : super(name);

  factory OutlineMember.fromMap(Map mapData) {
    String type = mapData["type"];
    OutlineMember entry;

    if (type == OutlineMethod._type) {
      entry = new OutlineMethod()..populateFromMap(mapData);
    } else if (type == OutlineProperty._type) {
      entry = new OutlineProperty()..populateFromMap(mapData);
    } else if (type == OutlineAccessor._type) {
      entry = new OutlineAccessor()..populateFromMap(mapData);
    }

    return entry;
  }

  /**
   * Populates values and children from a map
   */
  void populateFromMap(Map mapData) {
    super.populateFromMap(mapData);
    static = mapData["static"];
  }

  Map toMap() {
    return super.toMap()..addAll({
      "static": static,
    });
  }
}

/**
 * Defines a method entry in an [OutlineClass].
 */
class OutlineMethod extends OutlineMember {
  static String _type = "method";

  OutlineMethod([String name]) : super(name);

  Map toMap() {
    return super.toMap()..addAll({
      "type": _type,
    });
  }
}

/**
 * Defines a class variable entry in an [OutlineClass].
 */
class OutlineProperty extends OutlineMember {
  static String _type = "class-variable";
  String returnType = null;

  OutlineProperty([String name, this.returnType]) : super(name);

  void populateFromMap(Map mapData) {
    super.populateFromMap(mapData);
    returnType = mapData["returnType"];
  }

  Map toMap() {
    return super.toMap()..addAll({
      "type": _type,
      "returnType": returnType,
    });
  }
}

/**
 * Defines a class accessor (getter / setter) entry in an [OutlineClass].
 */
class OutlineAccessor extends OutlineMember {
  static String _type = "class-accessor";

  bool setter = false;

  OutlineAccessor([String name, this.setter]) : super(name);

  /**
   * Populates values and children from a map
   */
  void populateFromMap(Map mapData) {
    super.populateFromMap(mapData);
    setter = mapData["setter"];
  }

  Map toMap() {
    return super.toMap()..addAll({
      "type": _type,
      "setter": setter,
    });
  }
}

/**
 * Defines a top-level function entry in the [Outline].
 */
class OutlineTopLevelFunction extends OutlineTopLevelEntry {
  static String _type = "function";

  OutlineTopLevelFunction([String name]) : super(name);

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
  String returnType = null;


  OutlineTopLevelVariable([String name, this.returnType]) : super(name);

  void populateFromMap(Map mapData) {
    super.populateFromMap(mapData);
    returnType = mapData["returnType"];
  }

  Map toMap() {
    return super.toMap()..addAll({
      "type": _type,
      "returnType": returnType,
    });
  }
}
