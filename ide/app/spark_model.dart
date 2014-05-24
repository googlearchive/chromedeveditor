// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.model;

import 'dart:async';

import 'lib/ace.dart';
import 'lib/actions.dart';
import 'lib/app.dart';
import 'lib/editors.dart';
import 'lib/editor_area.dart';
import 'lib/event_bus.dart';
import 'lib/preferences.dart' as preferences;
import 'lib/workspace.dart' as ws;

abstract class SparkModel extends Application {
  static bool _instanceCreated = false;

  SparkModel() {
    assert(!_instanceCreated);
    _instanceCreated = true;
  }

  AceManager get aceManager;
  ThemeManager get aceThemeManager;
  KeyBindingManager get aceKeysManager;
  AceFontManager get aceFontManager;
  ws.Workspace get workspace;
  EditorManager get editorManager;
  EditorArea get editorArea;
  ActionManager get actionManager;

  EventBus get eventBus;

  preferences.PreferenceStore get localPrefs;
  preferences.PreferenceStore get syncPrefs;

  void showSuccessMessage(String message);
  void showErrorMessage(String title, String message);

  void onSplitViewUpdate(int position);
  void setGitSettingsResetDoneVisible(bool visible);

  /**
   * Should filter files in the tree view and return the success of the
   * operation, i.e. true if matches are found for [filter],
   * or [filter] is null.
   */
  Future<bool> filterFilesList(String filter);

  /**
   * Hide the splash screen; show the main UI.
   */
  void unveil();

  /**
   * Refresh the UI based on the changed model and/or flags and/or preferences.
   */
  void refreshUI();
}
