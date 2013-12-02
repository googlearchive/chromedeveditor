// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark;

import 'dart:html';
import 'package:polymer/polymer.dart' as polymer;

import 'spark.dart';
import 'lib/ace.dart';
import 'lib/utils.dart' as utils;
import 'package:spark_widgets/spark-overlay/spark-overlay.dart';
import 'package:spark_widgets/spark-icon/spark-icon.dart';
import 'package:spark_widgets/spark-icon-button/spark-icon-button.dart';

void main() {
  polymer.initPolymer().run(() {
    // TODO: hard-code developer mode to true for now.
    SparkPolymer spark = new SparkPolymer(true);
    spark.start();
  });
}

class SparkPolymer extends Spark {
  SparkPolymer(bool developerMode) : super(developerMode);

  @override
  void setupSplitView() {
    // We're using a Polymer-based splitview, so disable the default
    // by overriding this method to be empty.
  }

  @override
  void setupEditorThemes() {
    syncPrefs.getValue('aceTheme').then((String theme) {
      final selected = (theme != null) ? AceEditor.THEMES.indexOf(theme) : 0;

      (querySelector('#themeChooser') as dynamic)
        ..items = AceEditor.THEMES.map(_beautifyThemeName)
        ..selected = selected
        ..onClick.listen(_switchTheme);
      _switchTheme();
    });
  }

  @override
  void buildMenu() {
    // TODO: Implement this.
  }

  // TODO(terry): Hookup overlay dialog.
  @override
  void showStatus(String text, {bool error: false}) {
    Element element = querySelector("#status");
    element.text = text;
    SparkOverlay overlay = querySelector("#spark-dialog");
    if (overlay != null) {
      overlay.toggle();
    }
  }

  void _switchTheme([_]) {
    int selected =
        (querySelector('#themeChooser') as dynamic).selected;
    if (selected == -1)
      selected = 0;
    final String themeName = AceEditor.THEMES[selected];
    editor.theme = themeName;
    syncPrefs.setValue('aceTheme', themeName);
  }

  String _beautifyThemeName(String themeName) =>
      utils.capitalize(themeName).replaceAll('_', ' ');
}
