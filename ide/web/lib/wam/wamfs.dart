// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.wamfs;

import 'dart:async';
import 'dart:js' as js;
import 'dart:typed_data';

import '../javascript/js_completer.dart';

class WamFS {
  // Javascript object to wrap.
  js.JsObject _jsWamFS;

  WamFS() : _jsWamFS = new js.JsObject(js.context['WamFS'], []);

  Future connect(String extensionID, String mountPath) =>
      _callWamFSMethod('connect', [extensionID, mountPath]);

  Future copyFile(String source, String destination) =>
      _callWamFSMethod('copyFile', [source, destination]);

  Future<Uint8List> readFile(String filename) =>
      _callWamFSMethodWithResult('readFile', [filename]);

  Future writeDataToFile(String filename, Uint8List content) =>
      _callWamFSMethod('writeDataToFile', [filename, content]);

  Future writeStringToFile(String filename, String content) =>
      _callWamFSMethod('writeStringToFile', [filename, content]);

  Future executeCommand(
      String executablePath,
      List<String> commandLine,
      void printStdout(String string),
      void printStderr(String string)) {
    final js.JsObject jsCommandLine = new js.JsObject.jsify(commandLine);
    return _callWamFSMethod(
        'executeCommand',
        [executablePath, jsCommandLine, printStdout, printStderr]);
  }

  Future _callWamFSMethod(String methodName, List arguments) =>
      _callWamFSMethodImpl(methodName, arguments, true);

  Future _callWamFSMethodWithResult(String methodName, List arguments) =>
      _callWamFSMethodImpl(methodName, arguments, true);

  Future _callWamFSMethodImpl(
      String methodName, List arguments, bool withResult) {
    JsCompleter completer = new JsCompleter();
    List jsArguments = new List.from(arguments);
    jsArguments.addAll([
        withResult ? completer.onSuccessWithResult : completer.onSuccess,
        completer.onError
    ]);
    _jsWamFS.callMethod(methodName, jsArguments);
    return completer.future;
  }
}
