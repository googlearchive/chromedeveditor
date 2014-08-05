// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.wamfs;

import 'dart:async';
import 'dart:js' as js;
import 'dart:typed_data';

class WAMFS {

  // Javascript object to wrap.
  js.JsObject _jsWAMFS;

  WAMFS() {
    _jsWAMFS = new js.JsObject(js.context['WAMFS'], []);
  }

  Future connect(String extensionID, String mountPath) {
    Completer completer = new Completer();
    Function callback = () {
      completer.complete();
    };
    Function errorHandler = (error) {
      completer.completeError(error);
    };
    _jsWAMFS.callMethod('connect', [extensionID, mountPath, callback, errorHandler]);
    return completer.future;
  }

  Future copyFile(String source, String destination) {
    Completer completer = new Completer();
    Function callback = () {
      completer.complete();
    };
    Function errorHandler = (error) {
      completer.completeError(error);
    };
    _jsWAMFS.callMethod('copyFile', [source, destination, callback,
        errorHandler]);
    return completer.future;
  }

  Future<Uint8List> readFile(String filename) {
    Completer completer = new Completer();
    Function callback = (data) {
      completer.complete(data);
    };
    Function errorHandler = (error) {
      completer.completeError(error);
    };
    _jsWAMFS.callMethod('readFile', [callback, errorHandler]);
    return completer.future;
  }

  Future writeDataToFile(String filename, Uint8List content) {
    Completer completer = new Completer();
    Function callback = () {
      completer.complete();
    };
    Function errorHandler = (error) {
      completer.completeError(error);
    };
    _jsWAMFS.callMethod('writeDataToFile', [filename, content, callback,
        errorHandler]);
    return completer.future;
  }

  Future writeStringToFile(String filename, String content) {
    Completer completer = new Completer();
    Function callback = () {
      completer.complete();
    };
    Function errorHandler = (error) {
      completer.completeError(error);
    };
    _jsWAMFS.callMethod('writeStringToFile', [filename, content, callback,
        errorHandler]);
    return completer.future;
  }

  Future executeCommand(String executablePath, List<String> parameters,
      void printStdout(String string), void printStderr(String string)) {
    Completer completer = new Completer();
    Function callback = () {
      completer.complete();
    };
    Function errorHandler = (error) {
      completer.completeError(error);
    };
    _jsWAMFS.callMethod('executeCommand', [executablePath,
        new js.JsObject.jsify(parameters), printStdout, printStderr, callback,
        errorHandler]);
    return completer.future;
  }
}
