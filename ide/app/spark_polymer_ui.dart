// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_polymer.ui;

import 'dart:html';

import 'package:polymer/polymer.dart';

// BUG(ussuri): https://github.com/dart-lang/spark/issues/500
import 'packages/spark_widgets/common/spark_widget.dart';
import 'packages/spark_widgets/spark_suggest_box/spark_suggest_box.dart';

import 'spark_model.dart';
import 'lib/actions.dart';
import 'lib/search.dart';
import 'lib/workspace.dart';

@CustomTag('spark-polymer-ui')
class SparkPolymerUI extends SparkWidget {
  SparkModel _spark;

  @observable bool developerMode = false;
  @observable bool chromeOS = false;
  @observable SuggestOracle searchOracle;

  SparkPolymerUI.created() : super.created();

  void bindToSparkModel(SparkModel spark) {
    _spark = spark;

    developerMode = spark.developerMode;
    searchOracle = new SearchOracle(() => _spark.workspace, _selectFile);
    bindKeybindingDesc();
  }

  void _selectFile(Resource file) {
    _spark.editorArea.selectFile(
        file,
        forceOpen: true,
        replaceCurrent: false,
        switchesTab: true,
        forceFocus: true);
  }

  void onMenuSelected(CustomEvent event, var detail) {
    if (detail['isSelected']) {
      final actionId = detail['value'];
      final action = _spark.actionManager.getAction(actionId);
      action.invoke();
    }
  }

  void onThemeMinus(Event e) {
    _spark.aceThemeManager.dec(e);
  }

  void onThemePlus(Event e) {
    _spark.aceThemeManager.inc(e);
  }

  void onKeysMinus(Event e) {
    _spark.aceKeysManager.dec(e);
  }

  void onKeysPlus(Event e) {
    _spark.aceKeysManager.inc(e);
  }

  void onSplitterUpdate(CustomEvent e, var detail) {
    _spark.onSplitViewUpdate(detail['targetSize']);
  }

  void bindKeybindingDesc() {
    final items = getShadowDomElement('#mainMenu').querySelectorAll(
        'spark-menu-item');
    items.forEach((menuItem) {
      final actionId = menuItem.attributes['action-id'];
      final Action action = _spark.actionManager.getAction(actionId);
      action.bindings.forEach(
          (keyBind) => menuItem.description = keyBind.getDescription());
    });
  }

  void onResetGit() {
    _spark.syncPrefs.removeValue(['git-auth-info', 'git-user-info']);
    _spark.setGitSettingsResetDoneVisible(true);
  }

  void onResetPreference() {
    Element resultElement = getShadowDomElement('#preferenceResetResult');
    resultElement.text = '';
    _spark.syncPrefs.clear().then((_) {
      _spark.localPrefs.clear();
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
