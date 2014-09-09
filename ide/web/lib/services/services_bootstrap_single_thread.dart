// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.services_bootstrap;

import 'dart:async';

import 'services_common.dart';

IsolateHandler createIsolateHandler() {
  return new _IsolateHandlerSingleThreadImpl();  
}

/**
 * Implements [IsolateHandler] where the worker runs on the same isolate
 * as the host. This is used for debuggin/testing only.
 */
class _IsolateHandlerSingleThreadImpl implements IsolateHandler {
  //int _topCallId = 0;
  //final Map<String, Completer> _serviceCallCompleters = {};
  //final StreamController _readyController = new StreamController.broadcast();
  //final ReceivePort _receivePort = new ReceivePort();

  Stream<ServiceActionEvent> onIsolateMessage;
  Future onceIsolateReady;
  
  _IsolateHandlerSingleThreadImpl() {
  }

  @override
  Future<String> ping() {
    // TODO(rpaquay)
    return null;
  }

  @override
  Future<ServiceActionEvent> sendAction(ServiceActionEvent event) {
    // TODO(rpaquay)
    return null;
  }

  @override
  void sendResponse(ServiceActionEvent event) {
    // TODO(rpaquay)
  }

  @override
  void dispose() {
    // TODO(rpaquay)
  }
}
