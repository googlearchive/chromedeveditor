// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of spark.templates;

class ChromeAppWithPolymerJSTemplate extends SparkProjectTemplate {
  ChromeAppWithPolymerJSTemplate(
      String id, List<TemplateVar> globalVars, List<TemplateVar> localVars)
      : super._(id, globalVars, localVars);

  // TODO(ussuri): Add option to "never show again".
  Future showIntro(Project finalProject, utils.Notifier notifier) {
    final String packagesDir = bowerProperties.getPackagesDirName(finalProject);

    notifier.showMessage(
        "Action required",
        "Your new app will not run as is.\n\n"
        "This project template uses Polymer elements, which have "
        "known incompatibilities with the Content Security Policy (CSP), "
        "which is enforced by the Chrome Apps platform.\n\n"
        "In order to fix that, right-click the '$packagesDir' folder under "
        "your new project, '${finalProject.name}', and select "
        "'Refactor for CSP' from the context menu.");

    return new Future.value();
  }
}
