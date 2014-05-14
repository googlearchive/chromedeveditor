// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.services_impl;

import 'dart:async';
import 'dart:isolate';

import 'analyzer.dart' as analyzer;
import 'services_common.dart';
import 'compiler.dart';
import '../dart/sdk.dart';

void init(SendPort sendPort) {
  final ServicesIsolate servicesIsolate = new ServicesIsolate(sendPort);
}

/**
 * A `Function` that takes in a [ServiceActionEvent] as a request and returns
 * its response event in a [Future].
 */
typedef Future<ServiceActionEvent> RequestHandler(ServiceActionEvent request);

/**
 * Defines a handler for all worker-side service implementations.
 */
class ServicesIsolate {
  int _topCallId = 0;
  final SendPort _sendPort;

  // Fired when host originates a message
  Stream<ServiceActionEvent> onHostMessage;

  // Fired when host responds to message
  Stream<ServiceActionEvent> onResponseMessage;

  ChromeService chromeService;
  Map<String, ServiceImpl> _serviceImplsById = {};

  DartSdk sdk;

  ServicesIsolate(this._sendPort) {
    chromeService = new ChromeService(this);

    StreamController<ServiceActionEvent> hostMessageController =
        new StreamController();
    StreamController<ServiceActionEvent> responseMessageController =
        new StreamController.broadcast();

    onResponseMessage = responseMessageController.stream;
    onHostMessage = hostMessageController.stream;

    ReceivePort receivePort = new ReceivePort();
    _sendPort.send(receivePort.sendPort);

    _registerServiceImpl(new TestServiceImpl(this));

    receivePort.listen((arg) {
      if (arg is int) {
        _sendPort.send(arg);
      } else {
        ServiceActionEvent event = new ServiceActionEvent.fromMap(arg);
        if (event.response) {
          responseMessageController.add(event);
        } else {
          hostMessageController.add(event);
        }
      }
    });

    chromeService.getAppContents('sdk/dart-sdk.bz').then((List<int> sdkContents) {
      sdk = DartSdk.createSdkFromContents(sdkContents);

      _registerServiceImpl(new CompilerServiceImpl(this, sdk));
      _registerServiceImpl(new AnalyzerServiceImpl(this, sdk));

      onHostMessage.listen((ServiceActionEvent event) => _handleMessage(event));
    });
  }

  ServiceImpl getServiceImpl(String serviceId) {
    return _serviceImplsById[serviceId];
  }

  Future<ServiceActionEvent> _onResponseByCallId(String callId) {
    Completer<ServiceActionEvent> completer = new Completer<ServiceActionEvent>();
    // Added to avoid leaking subscriptions. Consider using a map of completers.
    StreamSubscription sub = null;
    sub = onResponseMessage.listen((ServiceActionEvent event) {
      if (event.callId == callId) {
        completer.complete(event);
        sub.cancel();
      }
    });
    return completer.future;
  }

  void _registerServiceImpl(ServiceImpl serviceImplementation) {
    _serviceImplsById[serviceImplementation.serviceId] = serviceImplementation;
  }

  Future<ServiceActionEvent> _handleMessage(ServiceActionEvent event) {
    Completer<ServiceActionEvent> completer = new Completer<ServiceActionEvent>();

    ServiceImpl service = getServiceImpl(event.serviceId);
    service.handleEvent(event).then((ServiceActionEvent responseEvent) {
      if (responseEvent != null) {
        _sendResponse(responseEvent);
        completer.complete();
      }
    });

    return completer.future;
  }

  // Sends a response message.
  void _sendResponse(ServiceActionEvent event, [Map data,
      bool expectResponse = false]) {
    // TODO(ericarnold): implement expectResponse
    event.response = true;
    var eventMap = event.toMap();
    if (data != null) {
      eventMap['data'] = data;
    }
    _sendPort.send(eventMap);
  }

  String _getNewCallId() => "iso_${_topCallId++}";

  // Sends action to host. Returns a future if expectResponse is true.
  Future<ServiceActionEvent> _sendAction(ServiceActionEvent event,
      [bool expectResponse = false]) {

    event.makeRespondable(_getNewCallId());

    var eventMap = event.toMap();
    _sendPort.send(eventMap);
    return _onResponseByCallId(event.callId);
  }
}

class TestServiceImpl extends ServiceImpl {
  TestServiceImpl(ServicesIsolate isolate) : super(isolate, 'test') {
    registerRequestHandler('shortTest', shortTest);
    registerRequestHandler('longTest', longTest);
    registerRequestHandler('readText', readText);
  }

  Future<ServiceActionEvent> shortTest(ServiceActionEvent request) {
    Map map = {"response": "short${request.data['name']}"};
    return new Future.value(request.createReponse(map));
  }

  Future<ServiceActionEvent> longTest(ServiceActionEvent request) {
    return isolate.chromeService.delay(1000).then((_) {
      Map map = {"response": "long${request.data['name']}"};
      return new Future.value(request.createReponse(map));
    });
  }

  Future<ServiceActionEvent> readText(ServiceActionEvent request) {
    String fileUuid = request.data['fileUuid'];
    return isolate.chromeService.getFileContents(fileUuid) .then((String contents) {
      return request.createReponse({"contents": contents});
    });
  }
}

class CompilerServiceImpl extends ServiceImpl {
  final DartSdk sdk;
  Compiler compiler;

  CompilerServiceImpl(ServicesIsolate isolate, this.sdk) :
      super(isolate, 'compiler') {

    compiler = Compiler.createCompilerFrom(sdk,
        new _ServiceContentsProvider(isolate.chromeService));

    registerRequestHandler('compileString', compileString);
    registerRequestHandler('compileFile', compileFile);
  }

  Future<ServiceActionEvent> compileString(ServiceActionEvent request) {
    String string = request.data['string'];
    return compiler.compileString(string).then((CompilerResult result) {
      return new Future.value(request.createReponse(result.toMap()));
    });
  }

  Future<ServiceActionEvent> compileFile(ServiceActionEvent request) {
    String fileUuid = request.data['fileUuid'];
    String project = request.data['project'];
    bool csp = request.data['csp'];

    return compiler.compileFile(fileUuid, csp: csp).then((CompilerResult result) {
      return new Future.value(request.createReponse(result.toMap()));
    });
  }
}

class _ServiceContentsProvider implements ContentsProvider {
  final ChromeService chromeService;

  _ServiceContentsProvider(this.chromeService);

  Future<String> getFileContents(String uuid) {
    if (uuid.startsWith('/')) uuid = uuid.substring(1);
    return chromeService.getFileContents(uuid);
  }

  Future<String> getPackageContents(String relativeUuid, String packageRef) {
    return chromeService.getPackageContents(relativeUuid, packageRef);
  }
}

class AnalyzerServiceImpl extends ServiceImpl {
  analyzer.ChromeDartSdk dartSdk;

  Map<String, analyzer.ProjectContext> _contexts = {};

  AnalyzerServiceImpl(ServicesIsolate isolate, DartSdk sdk) :
      super(isolate, 'analyzer') {
    dartSdk = analyzer.createSdk(sdk);

    registerRequestHandler('buildFiles', buildFiles);
    registerRequestHandler('createContext', createContext);
    registerRequestHandler('processContextChanges', processContextChanges);
    registerRequestHandler('disposeContext', disposeContext);
    registerRequestHandler('getOutlineFor', getOutlineFor);
    registerRequestHandler('getDeclarationFor', getDeclarationFor);
  }

  Future<analyzer.ChromeDartSdk> get dartSdkFuture => new Future.value(dartSdk);

  Future<ServiceActionEvent> buildFiles(ServiceActionEvent request) {
    List<Map> fileUuids = request.data["dartFileUuids"];
    return _buildFiles(fileUuids).then((errorsPerFile) {
      return request.createReponse({"errors": errorsPerFile});
    });
  }

  Future<Map<String, List<Map>>> _buildFiles(List<Map> fileUuids) {
      Map<String, List<Map>> errorsPerFile = {};

      return dartSdkFuture.then((analyzer.ChromeDartSdk sdk) {
        return Future.forEach(fileUuids, (String fileUuid) {
          return _processFile(sdk, fileUuid).then((analyzer.AnalyzerResult result) {
            List<analyzer.AnalysisError> errors = result.errors;
            List<Map> responseErrors = [];

            if (errors != null) {
              for (analyzer.AnalysisError error in errors) {
                AnalysisError responseError = new AnalysisError();
                responseError.message = error.message;
                responseError.offset = error.offset;
                analyzer.LineInfo_Location location = result.getLineInfo(error);
                responseError.lineNumber = location.lineNumber;
                responseError.errorSeverity =
                    _errorSeverityToInt(error.errorCode.errorSeverity);
                responseError.length = error.length;
                responseErrors.add(responseError.toMap());
              }
            }

            return responseErrors;
          }).then((List<Map> errors) {
            errorsPerFile[fileUuid] = errors;
          });
        });
      }).then((_) => errorsPerFile);
    }

    Future<ServiceActionEvent> createContext(ServiceActionEvent request) {
      String id = request.data['contextId'];
      _contexts[id] = new analyzer.ProjectContext(id, dartSdk,
          new _ServiceContentsProvider(isolate.chromeService));
      return new Future.value(request.createReponse());
    }

    Future<ServiceActionEvent> processContextChanges(ServiceActionEvent request) {
      String id = request.data['contextId'];

      List<String> addedUuids = request.data['added'];
      List<String> changedUuids = request.data['changed'];
      List<String> deletedUuids = request.data['deleted'];

      analyzer.ProjectContext context = _contexts[id];

      if (context != null) {
        return context.processChanges(addedUuids, changedUuids,
            deletedUuids).then((analyzer.AnalysisResultUuid result) {
          return new Future.value(request.createReponse(result.toMap()));
        });
      } else {
        return new Future.value(
            request.createErrorReponse('no context associated with id ${id}'));
      }
    }

    Future<ServiceActionEvent> disposeContext(ServiceActionEvent request) {
      String id = request.data['contextId'];
      _contexts.remove(id);
      return new Future.value(request.createReponse());
    }

    Future<ServiceActionEvent> getOutlineFor(ServiceActionEvent request) {
      var codeString = request.data['string'];
      return analyzer.analyzeString(dartSdk, codeString).then((result) {
        return request.createReponse(_getOutline(result.ast).toMap());
      });
    }

    Future<ServiceActionEvent> getDeclarationFor(ServiceActionEvent request) {
      analyzer.ProjectContext context = _contexts[request.data['contextId']];
      String fileUuid = request.data['fileUuid'];
      int offset = request.data['offset'];

      Declaration declaration = _getDeclarationFor(context, fileUuid, offset);
      return new Future.value(request.createReponse(
          declaration != null ? declaration.toMap() : null));
    }

    Declaration _getDeclarationFor(analyzer.ProjectContext context,
        String fileUuid, int offset) {
      analyzer.FileSource source = context.getSource(fileUuid);

      List<analyzer.Source> librarySources =
          context.context.getLibrariesContaining(source);

      if (librarySources.isEmpty) return null;

      analyzer.CompilationUnit ast =
          context.context.resolveCompilationUnit2(source, librarySources[0]);

      analyzer.AstNode node =
          new analyzer.NodeLocator.con1(offset).searchWithin(ast);
      if (node is! analyzer.SimpleIdentifier) return null;

      analyzer.Element element = analyzer.ElementLocator.locate(node);
      if (element == null) return null;

      if (element.nameOffset == -1 || element.source == null) {
        return null;
      }

      // TODO:(devoncarew): Handle sdk sources.
      if (element.source is! analyzer.FileSource) return null;

      analyzer.FileSource fileSource = element.source;

      return new Declaration(
          element.displayName, fileSource.uuid,
          element.nameOffset, element.name.length);
    }

    Outline _getOutline(analyzer.CompilationUnit ast) {
    Outline outline = new Outline();

    // Ideally, we'd get an AST back, even for very badly formed files.
    if (ast == null) return outline;

    // TODO(ericarnold): Need to implement modifiers
    // TODO(ericarnold): Need to implement types

    for (analyzer.Declaration declaration in ast.declarations) {
      if (declaration is analyzer.TopLevelVariableDeclaration) {
        analyzer.VariableDeclarationList variables = declaration.variables;

        for (analyzer.VariableDeclaration variable in variables.variables) {
          outline.entries.add(_populateOutlineEntry(
              new OutlineTopLevelVariable(variable.name.name,
                  variables.type.name.name),
              new _Range.fromAstNode(declaration),
              new _Range.fromAstNode(declaration)));
        }
      } else if (declaration is analyzer.ClassDeclaration) {
        OutlineClass outlineClass = new OutlineClass(declaration.name.name);
        outline.entries.add(
            _populateOutlineEntry(outlineClass,
                                  new _Range.fromAstNode(declaration.name),
                                  new _Range.fromAstNode(declaration)));

        for (analyzer.ClassMember member in declaration.members) {
          if (member is analyzer.MethodDeclaration) {
            if (member.isGetter || member.isSetter) {
              outlineClass.members.add(_populateOutlineEntry(
                  new OutlineAccessor(member.name.name, member.isSetter),
                  new _Range.fromAstNode(member.name),
                  new _Range.fromAstNode(member)));
            } else {
              outlineClass.members.add(_populateOutlineEntry(
                  new OutlineMethod(member.name.name),
                  new _Range.fromAstNode(member.name),
                  new _Range.fromAstNode(member)));
            }
          } else if (member is analyzer.FieldDeclaration) {
            analyzer.VariableDeclarationList fields = member.fields;
            for (analyzer.VariableDeclaration field in fields.variables) {
              outlineClass.members.add(_populateOutlineEntry(
                  new OutlineProperty(field.name.name, fields.type.name.name),
                  new _Range.fromAstNode(field),
                  new _Range.fromAstNode(field.parent)));
            }
          } else if (member is analyzer.ConstructorDeclaration) {
            analyzer.ConstructorDeclaration constructor = member;

            var nameIdentifier = constructor.name;
            String name = declaration.name.name +
                (nameIdentifier != null ? ".${nameIdentifier.name}" : "");
            _Range nameRange = new _Range(constructor.beginToken.offset,
                nameIdentifier == null ? constructor.beginToken.end :
                nameIdentifier.end);

            outlineClass.members.add(_populateOutlineEntry(
                new OutlineMethod(name),
                nameRange,
                new _Range.fromAstNode(declaration)));
          }
        }
      } else if (declaration is analyzer.FunctionDeclaration) {
        outline.entries.add(_populateOutlineEntry(
            new OutlineTopLevelFunction(declaration.name.name),
            new _Range.fromAstNode(declaration.name),
            new _Range.fromAstNode(declaration)));
      } else {
        print("${declaration.runtimeType} is unknown");
      }
    }

    return outline;
  }

  OutlineEntry _populateOutlineEntry(OutlineEntry outlineEntry, _Range name,
      _Range body) {
    outlineEntry.nameStartOffset = name.startOffset;
    outlineEntry.nameEndOffset = name.endOffset;
    outlineEntry.bodyStartOffset = body.startOffset;
    outlineEntry.bodyEndOffset = body.endOffset;
    return outlineEntry;
  }

  int _errorSeverityToInt(analyzer.ErrorSeverity severity) {
    if (severity == analyzer.ErrorSeverity.ERROR) {
      return ErrorSeverity.ERROR;
    } else  if (severity == analyzer.ErrorSeverity.WARNING) {
      return ErrorSeverity.WARNING;
    } else  if (severity == analyzer.ErrorSeverity.INFO) {
      return ErrorSeverity.INFO;
    } else {
      return ErrorSeverity.NONE;
    }
  }

  /**
   * Analyzes file and returns a Future with the [AnalyzerResult].
   */
  Future<analyzer.AnalyzerResult> _processFile(analyzer.ChromeDartSdk sdk, String fileUuid) {
    return isolate.chromeService.getFileContents(fileUuid)
        .then((String contents) => analyzer.analyzeString(sdk, contents))
        .then((analyzer.AnalyzerResult result) => result);
  }
}

class _Range {
  int startOffset = null;
  int endOffset = null;

  _Range(this.startOffset, this.endOffset);
  _Range.fromAstNode(analyzer.AstNode node) {
    startOffset = node.offset;
    endOffset = node.end;
  }
}

/**
 * Special service for calling back to chrome.
 */
class ChromeService {
  ServicesIsolate _isolate;

  ChromeService(this._isolate);

  ServiceActionEvent _createNewEvent(String actionId, [Map data]) {
    return new ServiceActionEvent("chrome", actionId, data);
  }

  Future<ServiceActionEvent> delay(int milliseconds) =>
      _sendAction(_createNewEvent("delay", {"ms": milliseconds}));

  /**
   * Return the contents of the file at the given path. The path is relative to
   * the Chrome app's directory.
   */
  Future<List<int>> getAppContents(String path) {
    return _sendAction(_createNewEvent("getAppContents", {"path": path}))
        .then((ServiceActionEvent event) => event.data['contents']);
  }

  Future<String> getFileContents(String uuid) =>
    _sendAction(_createNewEvent("getFileContents", {"uuid": uuid}))
        .then((ServiceActionEvent event) => event.data["contents"]);

  /**
   * Get the contents for the given package reference. [packageRef] should look
   * something like `package:foo/foo.dart`;
   */
  Future<String> getPackageContents(String relativeUuid, String packageRef) {
    var event = _createNewEvent("getPackageContents",
        {"relativeTo": relativeUuid, "packageRef": packageRef});
    return _sendAction(event).then((event) => event.data["contents"]);
  }

  Future<ServiceActionEvent> _sendAction(ServiceActionEvent event,
      [bool expectResponse = false]) {
    return _isolate._sendAction(event, expectResponse).
        then((ServiceActionEvent event) {
      if (event.error != true) {
        return event;
      } else {
        String error = event.data['error'];
        String stackTrace = event.data['stackTrace'];
        throw "ChromeService error: $error\n$stackTrace";
      }
    });
  }
}

/**
 * Provides an abstract class and helper code for service implementations.
 */
abstract class ServiceImpl {
  final String serviceId;
  final ServicesIsolate isolate;

  Map<String, RequestHandler> _responders = {};

  ServiceImpl(this.isolate, this.serviceId);

  void registerRequestHandler(String methodName, RequestHandler responder) {
    _responders[methodName] = responder;
  }

  Future<ServiceActionEvent> handleEvent(ServiceActionEvent event) {
    RequestHandler responder = _responders[event.actionId];

    if (responder == null) {
      return new Future.value(
          event.createErrorReponse("no such method: ${event.actionId}"));
    } else {
      Future f = responder(event);
      assert(f != null);
      return f.catchError((e, st) {
        return event.createErrorReponse('${e}\n${st}');
      });
    }
  }
}
