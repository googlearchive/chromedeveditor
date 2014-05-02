// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.flags;

class SparkFlags {
  bool developerMode;
  bool useLightEditorThemes;
  bool useDarkEditorThemes;
  bool get useEditorThemes => useLightEditorThemes || useDarkEditorThemes;

  static SparkFlags instance;

  SparkFlags._(bool developerMode, bool lightEditorThemes, bool darkEditorThemes) :
      this.developerMode = developerMode == true,
      this.useLightEditorThemes = lightEditorThemes == true,
      this.useDarkEditorThemes = darkEditorThemes == true;

  static void init(bool developerMode,
                   bool lightEditorThemes,
                   bool darkEditorThemes) {
    assert(instance == null);
    instance = new SparkFlags._(
        developerMode, lightEditorThemes, darkEditorThemes);
  }
}
