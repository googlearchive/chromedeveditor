// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_polymer.ui;

import 'dart:async';
import 'dart:html';

import 'package:polymer/polymer.dart';
import 'package:spark_widgets/common/spark_widget.dart';

import 'spark_model.dart';
import 'lib/workspace.dart';

@CustomTag('spark-polymer-ui')
class SparkPolymerUI extends SparkWidget {
  @observable bool developerMode = false;
  @observable bool chromeOS = false;

  SparkPolymerUI.created() : super.created();

  @override
  void enteredView() {
    super.enteredView();
  }

  void _selectFile(Resource file) {
    SparkModel.instance.editorArea.selectFile(
        file,
        forceOpen: true,
        replaceCurrent: false,
        switchesTab: true,
        forceFocus: true);
  }

  void onMenuSelected(CustomEvent event, var detail) {
    if (detail['isSelected']) {
      final actionId = detail['value'];
      final action = SparkModel.instance.actionManager.getAction(actionId);
      action.invoke();
    }
  }

  void onThemeMinus(Event e) {
    SparkModel.instance.aceThemeManager.dec(e);
  }

  void onThemePlus(Event e) {
    SparkModel.instance.aceThemeManager.inc(e);
  }

  void onKeysMinus(Event e) {
    SparkModel.instance.aceKeysManager.dec(e);
  }

  void onKeysPlus(Event e) {
    SparkModel.instance.aceKeysManager.inc(e);
  }

  void onSplitterUpdate(CustomEvent e, var detail) {
    SparkModel.instance.onSplitViewUpdate(detail['targetSize']);
  }

  void onResetGit() {
    SparkModel.instance.syncPrefs.removeValue(
        ['git-auth-info', 'git-user-info']);
    SparkModel.instance.setGitSettingsResetDoneVisible(true);
  }

  void onResetPreference() {
    Element resultElement = getShadowDomElement('#preferenceResetResult');
    resultElement.text = '';
    SparkModel.instance.syncPrefs.clear().then((_) {
      SparkModel.instance.localPrefs.clear();
    }).catchError((e) {
      resultElement.text = '<error reset preferences>';
    }).then((_) {
      resultElement.text = 'Preferences are reset. Restart Spark.';
    });
  }

  void handleAnchorClick(Event e) {
    e..preventDefault()..stopPropagation();
    AnchorElement anchor = e.target;
    window.open(anchor.href, '_blank');
  }
}
