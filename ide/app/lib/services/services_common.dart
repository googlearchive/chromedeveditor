// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.services_common;

import 'dart:async';

import '../workspace.dart';
import '../package_mgmt/package_manager.dart';
import '../package_mgmt/pub.dart';
import '../package_mgmt/pub_properties.dart';

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

  String toString() => '${serviceId}.${actionId}';
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

class CompileResult {
  String _output;
  List<CompileError> _problems;

  CompileResult.fromMap(Map map) {
    _output = map['output'];
    _problems = (map['problems'] as List).map(
        (p) => new CompileError.fromMap(p)).toList();
  }

  Future resolve(UuidResolver resolver) {
    _ContentRetriever retriever = new _ContentRetriever();

    // Find all files.
    problems.forEach((CompileError error) {
      error.file = resolver.getResource(error._uri);
      if (error.file != null) retriever.addFile(error.file);
    });

    // Get content.
    return retriever.loadContent().then((_) {
      // Calculate line numbers.
      problems.forEach((CompileError error) {
        error.line = retriever.getLineFor(error.file, error._offset);
      });
    });
  }

  bool get hasOutput => output != null;

  String get output => _output;

  List<CompileError> get problems => _problems;

  /// This is true if none of the reported problems were errors.
  bool getSuccess() => !_problems.any((p) => p.isError);
}

/**
 * The results of a dart2js compile.
 */
class CompileError {
  final String kind;
  final String message;
  File file;
  int line = 0;

  String _uri;
  int _offset;

  CompileError(this.kind, this.message, [this.file, this.line]);

  factory CompileError.fromMap(Map map) {
    CompileError result = new CompileError(map['kind'], map['message']);
    result._uri = map['uri'];
    result._offset = map['begin'];
    return result;
  }

  bool get isError => kind == 'error';

  String toString() =>
      '[${kind}] ${message} (${file == null ? '' : file.path}:${line})';
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

abstract class UuidResolver {
  File getResource(String uri);
}

/**
 * Defines an object containing information about a declaration.
 */
abstract class Declaration {
  final String name;

  Declaration(this.name);

  static String _nameFromMap(Map map) => map["name"];

  factory Declaration.fromMap(Map map) {
    if (map == null || map.isEmpty) return null;

    if (map["fileUuid"] != null) {
      return new SourceDeclaration.fromMap(map);
    } else {
      return new DocDeclaration.fromMap(map);
    }
  }

  Map toMap() {
    return {
      "name": name,
    };
  }
}

/**
 * Defines an object containing information about a declaration found in source.
 */
class SourceDeclaration extends Declaration {
  final String fileUuid;
  final int offset;
  final int length;

  SourceDeclaration(name, this.fileUuid, this.offset, this.length)
      : super(name);

  factory SourceDeclaration.fromMap(Map map) {
    if (map == null || map.isEmpty) return null;

    return new SourceDeclaration(Declaration._nameFromMap(map), map["fileUuid"],
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
    return super.toMap()..addAll({
      "fileUuid": fileUuid,
      "offset": offset,
      "length": length,
    });
  }

  String toString() => '${fileUuid} [${offset}:${length}]';
}

/**
 * Defines an object containing information about a declaration's doc location.
 */
class DocDeclaration extends Declaration {
  final String url;

  DocDeclaration(String name, this.url) : super(name);

  factory DocDeclaration.fromMap(Map map) {
    if (map == null || map.isEmpty) return null;

    return new DocDeclaration(Declaration._nameFromMap(map), map["url"]);
  }

  Map toMap() => super.toMap()..addAll({"url": url});
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
      "static": static
    });
  }
}

/**
 * Defines a method entry in an [OutlineClass].
 */
class OutlineMethod extends OutlineMember {
  static String _type = "method";

  String returnType;

  OutlineMethod([String name, this.returnType]) : super(name);

  void populateFromMap(Map mapData) {
    super.populateFromMap(mapData);
    returnType = mapData["returnType"];
  }

  Map toMap() {
    Map m = super.toMap();
    m['type'] = _type;
    if (returnType != null) m['returnType'] = returnType;
    return m;
  }
}

/**
 * Defines a class variable entry in an [OutlineClass].
 */
class OutlineProperty extends OutlineMember {
  static String _type = "class-variable";

  String returnType;

  OutlineProperty([String name, this.returnType]) : super(name);

  void populateFromMap(Map mapData) {
    super.populateFromMap(mapData);
    returnType = mapData["returnType"];
  }

  Map toMap() {
    Map m = super.toMap();
    m['type'] = _type;
    if (returnType != null) m['returnType'] = returnType;
    return m;
  }
}

/**
 * Defines a class accessor (getter / setter) entry in an [OutlineClass].
 */
class OutlineAccessor extends OutlineMember {
  static String _type = "class-accessor";

  String returnType;
  bool setter;

  OutlineAccessor([String name, this.returnType, this.setter = false]) :
      super(name);

  /**
   * Populates values and children from a map
   */
  void populateFromMap(Map mapData) {
    super.populateFromMap(mapData);
    returnType = mapData["returnType"];
    setter = mapData["setter"];
  }

  Map toMap() {
    Map m = super.toMap();
    m['type'] = _type;
    if (returnType != null) m['returnType'] = returnType;
    m['setter'] = setter;
    return m;
  }
}

/**
 * Defines a top-level function entry in the [Outline].
 */
class OutlineTopLevelFunction extends OutlineTopLevelEntry {
  static String _type = "function";

  String returnType;

  OutlineTopLevelFunction([String name, this.returnType]) : super(name);

  void populateFromMap(Map mapData) {
    super.populateFromMap(mapData);
    returnType = mapData["returnType"];
  }

  Map toMap() {
    Map m = super.toMap();
    m['type'] = _type;
    if (returnType != null) m['returnType'] = returnType;
    return m;
  }
}

/**
 * Defines a top-level variable entry in the [Outline].
 */
class OutlineTopLevelVariable extends OutlineTopLevelEntry {
  static String _type = "top-level-variable";

  String returnType;

  OutlineTopLevelVariable([String name, this.returnType]) : super(name);

  void populateFromMap(Map mapData) {
    super.populateFromMap(mapData);
    returnType = mapData["returnType"];
  }

  Map toMap() {
    Map m = super.toMap();
    m['type'] = _type;
    if (returnType != null) m['returnType'] = returnType;
    return m;
  }
}

/**
 * A class to retrieve the content for several files, and then provide
 * line-mapping information for those files.
 */
class _ContentRetriever {
  Map<File, String> fileMap = {};

  void addFile(File file) {
    if (!fileMap.containsKey(file)) {
      fileMap[file] = null;
    }
  }

  Future loadContent() {
    return Future.forEach(fileMap.keys, (File file) {
      return file.getContents().then((String contents) {
        fileMap[file] = contents;
      });
    });
  }

  int getLineFor(File file, int offset) {
    String source = fileMap[file];
    int lineCount = 0;

    if (source == null) return lineCount;

    for (int index = 0; index < source.length; index++) {
      if (source[index] == '\n') lineCount++;
      if (index == offset) return lineCount + 1;
    }

    return lineCount;
  }
}
