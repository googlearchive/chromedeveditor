// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark;

import 'dart:html';
import 'package:polymer/polymer.dart' as polymer;
import 'package:ace/ace.dart' as ace;

import 'spark.dart';
import 'lib/utils.dart' as utils;

void main() {
  polymer.initPolymer();
  SparkPolymer spark = new SparkPolymer();
  spark.start();
}

class SparkPolymer extends Spark {
  List<String> _themes = [
    ace.Theme.AMBIANCE,
    ace.Theme.MONOKAI,
    ace.Theme.PASTEL_ON_DARK,
    ace.Theme.TEXTMATE,
  ];

  SparkPolymer() : super();

  @override
  void setupEditorThemes() {
    syncPrefs.getValue('aceTheme').then((String theme) {
      final int selected = (theme != null) ? _themes.indexOf(theme) : 0;

      (querySelector('#themeChooser') as dynamic)
        ..items = _themes.map(_beautifyThemeName)
        ..selected = selected
        ..onClick.listen(_switchTheme);
      _switchTheme();
    });
  }

  void _switchTheme([_]) {
    int selected =
        (querySelector('#themeChooser') as dynamic).selected;
    if (selected == -1)
      selected = 0;
    final String themePath = new ace.Theme.named(_themes[selected]).path;
    editor.setTheme(themePath);
    syncPrefs.setValue('aceTheme', themePath);
  }

  String _beautifyThemeName(String themeName) {
    return utils.capitalize(themeName).replaceAll('_', ' ');
  }
}
