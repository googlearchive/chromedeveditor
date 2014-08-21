// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of spark.templates;

class ChromeAppWithPolymerJSTemplate extends ProjectTemplate {
  final String _PACKAGES_DIR = bowerProperties.packagesDirName;

  ChromeAppWithPolymerJSTemplate(
      String id, List<TemplateVar> globalVars, List<TemplateVar> localVars)
      : super._(id, globalVars, localVars);

  Future showIntro(utils.Notifier notifier) {
    notifier.showMessage(
        "Action required",
        "This project template includes Polymer elements, which have "
        "known incompatibilities with the Content Security Policy (CSP), "
        "which is enforced by Chrome apps: your app will not run as is.\n\n"
        "To fix, wait for the 'Getting Bower packages...' step to complete, "
        "right-click '$_PACKAGES_DIR' under the project and select "
        "'Refactor for CSP'.");
    return new Future.value();
  }
}
