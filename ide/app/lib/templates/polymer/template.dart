// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library spark.templates.polymer;

import '../templates.dart';
import '../../utils.dart' as utils;

class Template extends ProjectTemplate {
  Template(String id, List<TemplateVar> globalVars, List<TemplateVar> localVars)
      : super.internal(id, globalVars, localVars);

  @override
  List<TemplateVar> computeDerivedVars(
      List<TemplateVar>globalVars, List<TemplateVar>localVars) {
    final String projName =
        globalVars.singleWhere((e) => e.name == 'projectName').value;

    String tagName = projName.toLowerCase().replaceAll(new RegExp(r'\W'), '-');
    if (!tagName.contains('-')) {
      tagName = 'x-$tagName';
    }

    String className =
        utils.capitalize(tagName).replaceAllMapped(
            new RegExp(r'\W(.)'), (Match m) => utils.capitalize(m[1]));

    return <TemplateVar>[
      new TemplateVar('tagName', tagName),
      new TemplateVar('className', className)
    ];
  }
}
