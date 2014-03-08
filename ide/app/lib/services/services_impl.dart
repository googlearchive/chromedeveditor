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

  ServicesIsolate(this._sendPort) {
    chromeService = new ChromeService(this);

    StreamController<ServiceActionEvent> hostMessageController =
        new StreamController<ServiceActionEvent>.broadcast();
    StreamController<ServiceActionEvent> responseMessageController =
        new StreamController<ServiceActionEvent>.broadcast();

    onResponseMessage = responseMessageController.stream;
    onHostMessage = hostMessageController.stream;

    // Register each ServiceImpl:
    _registerServiceImpl(new CompilerServiceImpl(this));
    _registerServiceImpl(new TestServiceImpl(this));
    _registerServiceImpl(new AnalyzerServiceImpl(this));

    ReceivePort receivePort = new ReceivePort();
    _sendPort.send(receivePort.sendPort);

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

    onHostMessage.listen((ServiceActionEvent event) {
      _handleMessage(event);
    });
  }

  ServiceImpl getServiceImpl(String serviceId) {
    return _serviceImplsById[serviceId];
  }

  Future<ServiceActionEvent> _onResponseByCallId(String callId) {
    Completer<ServiceActionEvent> completer =
        new Completer<ServiceActionEvent>();
    onResponseMessage.listen((ServiceActionEvent event) {
      if (event.callId == callId) {
        completer.complete(event);
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

  // Sends action to host.  Returns a future if expectResponse is true.
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
  DartSdk sdk;
  Compiler compiler;

  Completer<ServiceActionEvent> _readyCompleter = new Completer();

  Future<ServiceActionEvent> get onceReady => _readyCompleter.future;

  CompilerServiceImpl(ServicesIsolate isolate) : super(isolate, 'compiler');

  Future<ServiceActionEvent> handleEvent(ServiceActionEvent event) {
    switch (event.actionId) {
      case "start":
        // TODO(ericarnold): Start should happen automatically on use.
        return _start().then((_) => new Future.value(event.createReponse(null)));
      case "dispose":
        return new Future.value(event.createReponse(null));
      case "compileString":
        return compiler.compileString(event.data['string'])
            .then((CompilerResult result)  {
          return new Future.value(event.createReponse(result.toMap()));
        });
      default:
        throw "Unknown action '${event.actionId}' sent to $serviceId service.";
    }
  }

  Future _start() {
    isolate.chromeService.getAppContents('sdk/dart-sdk.bin').then((List<int> sdkContents) {
      sdk = DartSdk.createSdkFromContents(sdkContents);
      compiler = Compiler.createCompilerFrom(sdk);
      _readyCompleter.complete();
    });

    return _readyCompleter.future;
  }
}

class AnalyzerServiceImpl extends ServiceImpl {
  AnalyzerServiceImpl(ServicesIsolate isolate) : super(isolate, 'analyzer');

  Future<analyzer.ChromeDartSdk> _dartSdkFuture;
  Future<analyzer.ChromeDartSdk> get dartSdkFuture {
    if (_dartSdkFuture == null) {
      _dartSdkFuture = isolate.chromeService.getAppContents('sdk/dart-sdk.bin')
          .then((List<int> sdkContents) => analyzer.createSdk(sdkContents));
    }
    return _dartSdkFuture;
  }

  Future<ServiceActionEvent> handleEvent(ServiceActionEvent event) {
    switch (event.actionId) {
      case "buildFiles":
        return buildFiles(event.data["dartFileUuids"])
            .then((Map<String, List<Map>> errorsPerFile) {
          return new Future.value(
              event.createReponse({"errors": errorsPerFile}));
        });
      case "getOutlineFor":
        return dartSdkFuture.then((analyzer.ChromeDartSdk sdk) {
          var codeString = event.data['string'];
          return analyzer.analyzeString(sdk, codeString,
              performResolution: false);
        }).then((analyzer.AnalyzerResult result) {
          return event.createReponse(getOutline(result.ast).toMap());
        });

      default:
        throw new ArgumentError(
            "Unknown action '${event.actionId}' sent to $serviceId service.");
    }
  }

  Outline getOutline(analyzer.CompilationUnit ast) {
    Outline outline = new Outline();

    // TODO(ericarnold): Need to implement modifiers
    // TODO(ericarnold): Need to implement types

    for (analyzer.Declaration declaration in ast.declarations) {
      OutlineTopLevelEntry outlineDeclaration;
      if (declaration is analyzer.TopLevelVariableDeclaration) {
        analyzer.VariableDeclarationList variables = declaration.variables;

        for (analyzer.VariableDeclaration variable in variables.variables) {
          outline.entries.add(populateOutlineEntry(
              new OutlineTopLevelVariable(variable.name.name), declaration));
        }
      } else {
        if (declaration is analyzer.ClassDeclaration) {
          outlineDeclaration = new OutlineClass(declaration.name.name);
          OutlineClass outlineClass = outlineDeclaration;
          for (analyzer.ClassMember member in declaration.members) {
            String name;
            if (member is analyzer.MethodDeclaration) {
              outlineClass.members.add(populateOutlineEntry(
                  new OutlineMethod(member.name.name), member));
            } else if (member is analyzer.FieldDeclaration) {
              analyzer.VariableDeclarationList fields = member.fields;
              for (analyzer.VariableDeclaration field in fields.variables) {
                outlineClass.members.add(populateOutlineEntry(
                    new OutlineProperty(field.name.name), field));
              }
            }
          }
        } else if (declaration is analyzer.FunctionDeclaration) {
          outlineDeclaration =
              new OutlineTopLevelFunction(declaration.name.name);
        } else {
          print("${declaration.runtimeType} is unknown");
        }

        outline.entries.add(populateOutlineEntry(
            outlineDeclaration, declaration));
      }
    }

    return outline;
  }

  OutlineEntry populateOutlineEntry(
      OutlineEntry outlineEntry, analyzer.ASTNode node) {
    outlineEntry.startOffset = node.beginToken.offset;
    outlineEntry.endOffset = node.endToken.end;
    return outlineEntry;
  }

  Future<Map<String, List<Map>>> buildFiles(List<Map> fileUuids) {
    Map<String, List<Map>> errorsPerFile = {};

    return dartSdkFuture.then((analyzer.ChromeDartSdk sdk) {
      return Future.forEach(fileUuids, (String fileUuid) {
        return _processFile(sdk, fileUuid)
            .then((analyzer.AnalyzerResult result) {
              List<analyzer.AnalysisError> errors = result.errors;
              List<Map> responseErrors = [];
              if (errors != null) {
                for (analyzer.AnalysisError error in errors) {
                  AnalysisError responseError =
                      new AnalysisError();
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
        .then((String contents) =>
            analyzer.analyzeString(sdk, contents, performResolution: false))
        .then((analyzer.AnalyzerResult result) => result);
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
    }

    Future f = responder(event);
    assert(f != null);
    return f;
  }
}
