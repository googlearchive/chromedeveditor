// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_polymer;

import 'dart:html';

import 'package:bootjack/bootjack.dart' as bootjack;
import 'package:polymer/polymer.dart' as polymer;

import 'spark.dart';
import 'lib/ace.dart';
import 'lib/utils.dart' as utils;

void main() {
  polymer.initPolymer();

  // TODO: hard-code developer mode to true for now.
  SparkPolymer spark = new SparkPolymer(true);
  spark.start();
}

class SparkPolymer extends Spark {
  SparkPolymer(bool developerMode) : super(developerMode);

  //
  // Override some parts of the parent's ctor:
  //

  @override
  void initAnalytics() => super.initAnalytics();

  @override
  void initWorkspace() => super.initWorkspace();

  @override
  void initEditor() => super.initEditor();

  @override
  void initEditorManager() => super.initEditorManager();

  @override
  void initEditorArea() => super.initEditorArea();

  @override
  void initSplitView() {
    // We're using a Polymer-based splitview, so disable the default.
  }

  @override
  void initEditorThemes() {
    super.initEditorThemes();
//    syncPrefs.getValue('aceTheme').then((String theme) {
//      final selected = (theme != null) ? AceEditor.THEMES.indexOf(theme) : 0;

//      (querySelector('#themeChooser') as dynamic)
//        ..items = AceEditor.THEMES.map(_beautifyThemeName)
//        ..selected = selected
//        ..onClick.listen(_switchTheme);
//      _switchTheme();
//    });
  }

  @override
  void initFilesController() => super.initFilesController();

  @override
  void initLookAndFeel() {
    // Init the Bootjack library (a wrapper around Bootstrap).
    bootjack.Bootjack.useDefault();
  }

  @override
  void createActions() => super.createActions();

  @override
  void initToolbar() => super.initToolbar();

  @override
  void buildMenu() => super.buildMenu();

  //
  // - End parts of the parent's ctor.
  //

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
