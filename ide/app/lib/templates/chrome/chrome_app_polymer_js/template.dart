// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of spark.templates;

class ChromeAppWithPolymerJSTemplate extends ProjectTemplate {
  ChromeAppWithPolymerJSTemplate(
      String id, List<TemplateVar> globalVars, List<TemplateVar> localVars)
      : super._(id, globalVars, localVars);

  Future showIntro(utils.Notifier notifier) {
    notifier.showMessage(
        "Action required",
        "This project template includes Polymer elements. These elements have "
        "known incompatibilities with the Content Security Policy (CSP), "
        "which is enforced by Chrome apps.\n\n"
        "To fix these CSP incompatibilities, wait for the "
        "'Getting Bower packages...' step to complete, then right-click "
        "'bower_components' under the new project and select "
        "'Refactor for CSP' in the context menu.");
    return new Future.value();
  }
}
