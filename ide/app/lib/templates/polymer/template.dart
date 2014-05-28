// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of spark.templates;

class PolymerTemplate extends ProjectTemplate {
  PolymerTemplate(
      String id, List<TemplateVar> globalVars, List<TemplateVar> localVars)
      : super._(id, globalVars, localVars) {
    final String projName = _vars['projectName'].value;

    String tagName = projName.toLowerCase().replaceAll(new RegExp(r'\W|_'), '-');
    if (!tagName.contains('-')) {
      tagName = 'x-$tagName';
    } else if (tagName.startsWith('-')) {
      tagName = 'x$tagName';
    }

    _addOrReplaceVars([new TemplateVar('tagName', tagName)]);
  }
}
