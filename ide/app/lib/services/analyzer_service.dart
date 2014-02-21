// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.services_impl.analyzer;

import "dart:async";

import "../../services_impl.dart";
import '../analyzer.dart';
import '../utils.dart';

class AnalyzerServiceImpl extends ServiceImpl {
  AnalyzerServiceImpl(ServicesIsolate isolate) : super(isolate);

  Future<ServiceActionEvent> handleEvent(ServiceActionEvent event) {

  }
}

// Used to avoid 'print hidden' warning
void print(var message) => sendPrint(message);