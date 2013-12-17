// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.model;

import 'lib/ace.dart';
import 'lib/actions.dart';
import 'lib/editorarea.dart';
import 'lib/editors.dart';
import 'lib/preferences.dart' as preferences;
import 'lib/workspace.dart' as ws;

abstract class SparkModel {
  bool get developerMode;

  AceContainer get aceContainer;
  ThemeManager get aceThemeManager;
  KeyBindingManager get aceKeysManager;
  ws.Workspace get workspace;
  EditorManager get editorManager;
  EditorArea get editorArea;

  preferences.PreferenceStore get localPrefs;
  preferences.PreferenceStore get syncPrefs;

  ActionManager get actionManager;
}
