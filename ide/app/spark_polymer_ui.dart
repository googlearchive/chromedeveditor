// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_polymer.ui;

import 'dart:html';

import 'package:polymer/polymer.dart';
import 'package:spark_widgets/common/spark_widget.dart';

import 'spark_flags.dart';
import 'spark_model.dart';

import 'lib/event_bus.dart';
import 'lib/platform_info.dart';

@CustomTag('spark-polymer-ui')
class SparkPolymerUI extends SparkWidget {
  SparkModel _model;

  // NOTE: The initial values have to be true so the app can find all the
  // UI elements it theoretically could need.
  @observable bool developerMode = true;
  @observable bool useAceThemes = true;
  @observable bool chromeOS = true;

  SparkPolymerUI.created() : super.created();

  @override
  void enteredView() {
    super.enteredView();
  }

  void modelReady(SparkModel model) {
    assert(_model == null);
    _model = model;
    refreshFromModel();
    // Changed selection may mean some menu items become disabled.
    // TODO(ussuri): Perhaps listen to more events, e.g. tab switch.
    _model.eventBus
        .onEvent(BusEventType.FILES_CONTROLLER__SELECTION_CHANGED).listen((_) {
      refreshFromModel();
    });
  }

  void refreshFromModel() {
    // TODO(ussuri): This also could possibly be done using PathObservers.
    developerMode = SparkFlags.developerMode;
    useAceThemes = SparkFlags.useAceThemes;
    chromeOS = PlatformInfo.isCros;
  }

  void onMenuSelected(CustomEvent event, var detail) {
    if (detail['isSelected']) {
      final actionId = detail['value'];
      final action = _model.actionManager.getAction(actionId);
      action.invoke();
    }
  }

  void onThemeMinus(Event e) {
    _model.aceThemeManager.prevTheme(e);
  }

  void onThemePlus(Event e) {
    _model.aceThemeManager.nextTheme(e);
  }

  void onKeysMinus(Event e) {
    _model.aceKeysManager.dec(e);
  }

  void onKeysPlus(Event e) {
    _model.aceKeysManager.inc(e);
  }

  void onSplitterUpdate(CustomEvent e, var detail) {
    _model.onSplitViewUpdate(detail['targetSize']);
  }

  void onResetGit() {
    _model.syncPrefs.removeValue(['git-auth-info', 'git-user-info']);
    _model.setGitSettingsResetDoneVisible(true);
  }

  void onResetPreference() {
    Element resultElement = getShadowDomElement('#preferenceResetResult');
    resultElement.text = '';
    _model.syncPrefs.clear().then((_) {
      _model.localPrefs.clear();
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
