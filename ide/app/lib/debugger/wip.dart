// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A library to speak the Webkit Inspection Protocol (WIP).
 */
library spark.wip;

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:html';

class WipConnection {
  /**
   * The WebSocket URL.
   */
  final String url;

  final WebSocket _ws;

  int _nextId = 0;

  WipConsole console;
  WipDebugger debugger;
  WipPage page;
  WipRuntime runtime;

  Map _domains = {};

  Map<int, Completer> _completers = {};

  StreamController<WipConnection> _closeController = new StreamController.broadcast();

  static Future<WipConnection> connect(String url) {
    StreamSubscription openSubscription;
    StreamSubscription closeSubscription;

    Completer completer = new Completer();
    WebSocket socket = new WebSocket(url);

    openSubscription = socket.onOpen.listen((e) {
      openSubscription.cancel();
      closeSubscription.cancel();
      completer.complete(new WipConnection._(url, socket));
    });

    closeSubscription = socket.onClose.listen((e) {
      openSubscription.cancel();
      closeSubscription.cancel();
      completer.completeError(e);
    });

    return completer.future;
  }

  WipConnection._(this.url, this._ws) {
    console = new WipConsole(this);
    debugger = new WipDebugger(this);
    page = new WipPage(this);
    runtime = new WipRuntime(this);

    _ws.onClose.listen((_) => _handleClose());
    _ws.onMessage.listen((MessageEvent e) {
      _Event event = new _Event._fromMap(JSON.decode(e.data));

      if (event.isNotification) {
        _handleNotification(event);
      } else {
        _handleResponse(event);
      }
    });
  }

  Stream<WipConnection> get onClose => _closeController.stream;

  void close() => _ws.close();

  String toString() => url;

  void _registerDomain(String domainId, WipDomain domain) {
    _domains[domainId] = domain;
  }

  Future<_Event> _sendCommand(_Event event) {
    Completer completer = new Completer();
    event.id = _nextId++;
    _completers[event.id] = completer;
    _ws.sendString(event.toJson());
    return completer.future;
  }

  void _handleNotification(_Event event) {
    String domainId = event.method;
    int index = domainId.indexOf('.');
    if (index != -1) {
      domainId = domainId.substring(0, index);
    }
    if (_domains.containsKey(domainId)) {
      _domains[domainId]._handleNotification(event);
    } else {
      _log('unhandled event notification: ${event.method}');
    }
  }

  void _handleResponse(_Event event) {
    Completer completer = _completers.remove(event.id);

    assert(completer != null);

    if (event.hasError) {
      completer.completeError(new WipError(event));
    } else {
      completer.complete(new WipResponse(event));
    }
  }

  void _log(String str) {
    print(str);
  }

  void _handleClose() {
    _closeController.add(this);
  }
}

abstract class WipObject {
  final Map map;

  WipObject(this.map);
}

class WipEvent extends WipObject {
  WipEvent(Map map) : super(map);

  String get method => map['method'];
  Map get params => map['params'];

  String toString() => '${method}()';
}

class WipError {
  final int id;
  final dynamic error;

  WipError(_Event event) : id = event.id, error = event.error;

  String toString() => '${error}';
}

class WipResponse {
  final int id;
  final Map result;

  WipResponse(_Event event) : id = event.id, result = event.result;

  String toString() => '${result}';
}

abstract class WipDomain {
  Map<String, Function> _callbacks = {};

  WipConnection connection;

  WipDomain(this.connection);

  void _register(String method, Function callback) {
    _callbacks[method] = callback;
  }

  void _handleNotification(_Event event) {
    Function f = _callbacks[event.method];
    if (f != null) f(event);
  }

  Future<_Event> _sendSimpleCommand(String method) {
    return connection._sendCommand(new _Event(method));
  }

  Future<_Event> _sendCommand(_Event event) => connection._sendCommand(event);
}

class WipConsole extends WipDomain {
  StreamController<ConsoleMessageEvent> _message = new StreamController.broadcast();
  StreamController _cleared = new StreamController.broadcast();

  ConsoleMessageEvent _lastMessage;

  WipConsole(WipConnection connection): super(connection) {
    connection._registerDomain('Console', this);

    _register('Console.messageAdded', _messageAdded);
    _register('Console.messageRepeatCountUpdated', _messageRepeatCountUpdated);
    _register('Console.messagesCleared', _messagesCleared);
  }

  Future enable() => _sendSimpleCommand('Console.enable');
  Future disable() => _sendSimpleCommand('Console.disable');
  Future clearMessages() => _sendSimpleCommand('Console.clearMessages');

  Stream<ConsoleMessageEvent> get onMessage => _message.stream;
  Stream get onCleared => _cleared.stream;

  void _messageAdded(_Event event) {
    _lastMessage = new ConsoleMessageEvent(event);
    _message.add(_lastMessage);
  }

  void _messageRepeatCountUpdated(_Event event) {
    if (_lastMessage != null) {
      _lastMessage.params['repeatCount'] = event.params['count'];
      _message.add(_lastMessage);
    }
  }

  void _messagesCleared(_Event event) {
    _lastMessage = null;
    _cleared.add(null);
  }
}

class WipDebugger extends WipDomain {
  StreamController _pausedController = new StreamController.broadcast();
  StreamController _resumedController = new StreamController.broadcast();

  Map<String, WipScript> _scripts = {};

  WipDebugger(WipConnection connection): super(connection) {
    connection._registerDomain('Debugger', this);

    // TODO:
    //_register('Debugger.breakpointResolved', _breakpointResolved);
    _register('Debugger.globalObjectCleared', _globalObjectCleared);
    _register('Debugger.paused', _paused);
    _register('Debugger.resumed', _resumed);
    //_register('Debugger.scriptFailedToParse', _scriptFailedToParse);
    _register('Debugger.scriptParsed', _scriptParsed);
  }

  Future enable() => _sendSimpleCommand('Debugger.enable');
  Future disable() => _sendSimpleCommand('Debugger.disable');

  Future<String> getScriptSource(String scriptId) {
    return _sendCommand(new _Event(
        'Debugger.getScriptSource', {'scriptId': scriptId})).then((_Event event) {
      return event.result['scriptSource'];
    });
  }

  Future pause() => _sendSimpleCommand('Debugger.pause');
  Future resume() => _sendSimpleCommand('Debugger.resume');

  Future stepInto() => _sendSimpleCommand('Debugger.stepInto');
  Future stepOut() => _sendSimpleCommand('Debugger.stepOut');
  Future stepOver() => _sendSimpleCommand('Debugger.stepOver');

  /**
   * State should be one of "all", "none", or "uncaught".
   */
  Future setPauseOnExceptions(String state) {
    var event = new _Event('Debugger.setPauseOnExceptions', {'state': state});
    return connection._sendCommand(event);
  }

  Stream get onPaused => _pausedController.stream;
  Stream get onResumed => _resumedController.stream;

  WipScript getScript(String scriptId) => _scripts[scriptId];

  void _globalObjectCleared(_Event event) {
    _scripts.clear();
  }

  void _paused(_Event event) {
    _pausedController.add(new DebuggerPausedEvent(event));
  }

  void _resumed(_Event event) {
    _resumedController.add(null);
  }

  void _scriptParsed(_Event event) {
    WipScript script = new WipScript(event.params);
    _scripts[script.scriptId] = script;
    print(script);
  }
}

class WipPage extends WipDomain {
  WipPage(WipConnection connection): super(connection) {
    connection._registerDomain('Page', this);

    // TODO:
    // Page.loadEventFired
    // Page.domContentEventFired
  }

  Future enable() => _sendSimpleCommand('Page.enable');
  Future disable() => _sendSimpleCommand('Page.disable');

  Future navigate(String url) {
    return connection._sendCommand(new _Event('Page.navigate', {'url': url}));
  }

  Future reload({bool ignoreCache, String scriptToEvaluateOnLoad}) {
    _Event event = new _Event('Page.navigate');

    if (ignoreCache != null) {
      event.addParam('ignoreCache', ignoreCache);
    }

    if (scriptToEvaluateOnLoad != null) {
      event.addParam('scriptToEvaluateOnLoad', scriptToEvaluateOnLoad);
    }

    return connection._sendCommand(event);
  }
}

class WipRuntime extends WipDomain {
  WipRuntime(WipConnection connection): super(connection) {
    connection._registerDomain('Page', this);
  }
}

/**
 * See [WipConsole.onMessage].
 */
class ConsoleMessageEvent extends WipEvent {
  ConsoleMessageEvent(_Event event): super(event.map);

  Map get _message => params['message'];

  String get text => _message['text'];
  String get level => _message['level'];
  String get url => _message['url'];
  int get repeatCount => _message['repeatCount'];

  Iterable<WipCallFrame> getStackTrace() {
    if (_message.containsKey('stackTrace')) {
      return params['stackTrace'].map((frame) => new WipConsoleCallFrame(frame));
    } else {
      return [];
    }
  }

  String toString() => text;
}

class WipConsoleCallFrame extends WipObject {
  WipConsoleCallFrame(Map m): super(m);

  int get columnNumber => map['columnNumber'];
  String get functionName => map['functionName'];
  int get lineNumber => map['lineNumber'];
  String get scriptId => map['scriptId'];
  String get url => map['url'];
}

class DebuggerPausedEvent extends WipEvent {
  DebuggerPausedEvent(_Event event): super(event.map);

  String get reason => params['reason'];
  Object get data => params['data'];

  Iterable<WipCallFrame> getCallFrames() {
    return params['callFrames'].map((frame) => new WipCallFrame(frame));
  }

  String toString() => 'paused: ${reason}';
}

class ScriptParsedEvent extends WipEvent {
  ScriptParsedEvent(Map params): super(params);

  String get scriptId => params['scriptId'];
  String get url => params['url'];
  int get startLine => params['startLine'];
  int get startColumn => params['startColumn'];
  int get endLine => params['endLine'];
  int get endColumn => params['endColumn'];
  bool get isContentScript => params['isContentScript'];
  String get sourceMapURL => params['sourceMapURL'];
}

class WipCallFrame extends WipObject {
  WipCallFrame(Map params): super(params);

  String get callFrameId => map['callFrameId'];
  String get functionName => map['functionName'];
  WipLocation get location => new WipLocation(map['location']);
  WipRemoteObject get thisObject => new WipRemoteObject(map['this']);

  Iterable<WipScope> getScopeChain() {
    return map['scopeChain'].map((scope) => new WipScope(scope));
  }

  String toString() => '[${functionName}]';
}

class WipLocation extends WipObject {
  WipLocation(Map params): super(params);

  int get columnNumber => map['columnNumber'];
  int get lineNumber => map['lineNumber'];
  String get scriptId => map['scriptId'];

  String toString() => '[${scriptId}:${lineNumber}:${columnNumber}]';
}

class WipScript extends WipObject {
  WipScript(Map m): super(m);

  String get scriptId => map['scriptId'];
  String get url => map['url'];
  int get startLine => map['startLine'];
  int get startColumn => map['startColumn'];
  int get endLine => map['endLine'];
  int get endColumn => map['endColumn'];
  bool get isContentScript => map['isContentScript'];
  String get sourceMapURL => map['sourceMapURL'];

  String toString() => '[script ${scriptId}: ${url}]';
}

class WipScope extends WipObject {
  WipScope(Map params): super(params);

  // "catch", "closure", "global", "local", "with"
  String get scope => map['scope'];

  /**
   * Object representing the scope. For global and with scopes it represents the
   * actual object; for the rest of the scopes, it is artificial transient
   * object enumerating scope variables as its properties.
   */
  WipRemoteObject get object => new WipRemoteObject(map['object']);
}

class WipRemoteObject extends WipObject {
  WipRemoteObject(Map map): super(map);

  String get className => map['className'];
  String get description => map['description'];
  String get objectId => map['objectId'];
  String get subtype => map['subtype'];
  String get type => map['type'];
  Object get value => map['value'];
}

class _Event {
  final Map map;

  _Event(String method, [Map params]) : map = {} {
    map['method'] = method;

    if (params != null) {
      map['params'] = params;
    }
  }

  _Event._fromMap(this.map);

  String get method => map['method'];

  int get id => map['id'];

  set id(int value) {
    map['id'] = value;
  }

  bool get isNotification => !map.containsKey('id');

  bool get hasError => map.containsKey('error');
  Object get error => map['error'];

  Map get result => map['result'];

  Map get params => map['params'];

  void addParam(String key, Object value) {
    map[key] = value;
  }

  String toJson() => JSON.encode(map);

  String toString() => isNotification ? '${method}()' : '${method}() [${id}]';
}
