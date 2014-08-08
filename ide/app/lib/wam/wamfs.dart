// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.wamfs;

import 'dart:async';
import 'dart:js' as js;
import 'dart:typed_data';

import '../javascript/js_completer.dart';

class WAMFS {

  // Javascript object to wrap.
  js.JsObject _jsWamFS;

  WAMFS() {
    _jsWamFS = new js.JsObject(js.context['WamFS'], []);
  }

  Future _callWamFSMethod(String methodName, List arguments) {
    JsCompleter completer = new JsCompleter();
    List jsArguments = new List.from(arguments);
    jsArguments.addAll([completer.onSuccess, completer.onError]);
    _jsWamFS.callMethod(methodName, jsArguments);
    return completer.future;
  }

  Future _callWamFSMethodWithResult(String methodName, List arguments) {
    JsCompleter completer = new JsCompleter();
    List jsArguments = new List.from(arguments);
    jsArguments.addAll([completer.onSuccessWithResult, completer.onError]);
    _jsWamFS.callMethod(methodName, jsArguments);
    return completer.future;
  }

  Future connect(String extensionID, String mountPath) {
    return _callWamFSMethod('connect', [extensionID, mountPath]);
  }

  Future copyFile(String source, String destination) {
    return _callWamFSMethod('copyFile', [source, destination]);
  }

  Future<Uint8List> readFile(String filename) {
    return _callWamFSMethodWithResult('readFile', [filename]);
  }

  Future writeDataToFile(String filename, Uint8List content) {
    return _callWamFSMethod('writeDataToFile', [filename, content]);
  }

  Future writeStringToFile(String filename, String content) {
    return _callWamFSMethod('writeStringToFile', [filename, content]);
  }

  Future executeCommand(String executablePath, List<String> parameters,
      void printStdout(String string), void printStderr(String string)) {
    return _callWamFSMethod('executeCommand', [executablePath,
        new js.JsObject.jsify(parameters), printStdout, printStderr]);
  }
}
