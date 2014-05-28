// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of spark.templates;

class PolymerDartTemplate extends PolymerTemplate {
  PolymerDartTemplate(
      String id, List<TemplateVar> globalVars, List<TemplateVar> localVars)
      : super(id, globalVars, localVars) {
    // Alter the source name produced by [PolymerTemplate] to satisfy
    // Polymer Dart requirements dictated by Pub.
    TemplateVar sourceName = _vars['sourceName'];
    sourceName.value = sourceName.value.replaceAll('-', '_');
  }
}
