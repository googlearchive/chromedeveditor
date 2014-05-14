// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library spark.templates.bower_deps;

import '../../templates.dart';

class Template extends ProjectTemplate {
  Template(String id, List<TemplateVar> globalVars, List<TemplateVar> localVars)
      : super.internal(id, globalVars, localVars);

  @override
  List<TemplateVar> computeDerivedVars(
      List<TemplateVar>globalVars, List<TemplateVar>localVars) {
    final List<TemplateVar> derivedVars = [];
    return derivedVars;
  }
}
