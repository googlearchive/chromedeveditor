// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of spark.templates;

class PolymerDartTemplate extends PolymerTemplate {
  PolymerDartTemplate(
      String id, List<TemplateVar> globalVars, List<TemplateVar> localVars)
      : super(id, globalVars, localVars) {
    final String tagName = _vars['tagName'].value;
    final String className =
        utils.capitalize(tagName).replaceAllMapped(
            new RegExp(r'\W(.)'), (Match m) => utils.capitalize(m[1]));
    // Override the standard source name with one matching the generated tag.
    final String sourceName = tagName.replaceAll('-', '_');

    _addOrReplaceVars([
        new TemplateVar('className', className),
        new TemplateVar('sourceName', sourceName)
    ]);
  }
}
