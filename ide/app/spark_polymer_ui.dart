// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_polymer.ui;

import 'dart:html';
import 'dart:async';

import 'package:polymer/polymer.dart';

// BUG(ussuri): https://github.com/dart-lang/spark/issues/500
import 'packages/spark_widgets/common/spark_widget.dart';
import 'packages/spark_widgets/spark_suggest/spark_suggest_box.dart';

import 'spark_model.dart';
import 'lib/search.dart';

@CustomTag('spark-polymer-ui')
class SparkPolymerUI extends SparkWidget {
  @observable bool developerMode = false;
  @observable SuggestOracle searchOracle;

  SparkPolymerUI.created() : super.created() {
    searchOracle = new SearchOracle(
        () => SparkModel.instance.workspace,
        (f) => SparkModel.instance.editorArea.selectFile(
            f, forceOpen: true, replaceCurrent: false, switchesTab: true));
    Timer.run(() => bindKeybindingDesc());
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

  void onSplitterUpdate(int position) {
    SparkModel.instance.onSplitViewUpdate(position);
  }

  void bindKeybindingDesc() {
    final items = getShadowDomElement('#mainMenu').querySelectorAll('spark-menu-item');
    items.forEach((menuItem) {
      final actionId = menuItem.attributes['action-id'];
      final action = SparkModel.instance.actionManager.getAction(actionId);
      action.bindings.forEach((keyBind) => menuItem.description = keyBind.getDescription());
    });
  }

  void onResetGit() {
    SparkModel.instance.syncPrefs.setValue('git-auth-info', null);
    SparkModel.instance.syncPrefs.setValue('git-user-info', null);
    SparkModel.instance.setGitSettingsResetDoneVisible(true);
  }

  void onResetPreference() {
    Element resultElement = getShadowDomElement('#preferenceResetResult')..text = '';
    SparkModel.instance.syncPrefs.clear().then((_) {
      SparkModel.instance.localPrefs.clear();
    }).catchError((e) {
      resultElement.text = '<error reset preferences>';
    }).then((_) {
      resultElement.text = 'Preferences are reset. Restart Spark.';
    });
  }
}
