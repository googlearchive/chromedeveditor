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

  // NOTE: The initial values for these have to be true, because the app
  // uses querySelector to find the affected elements that would be not
  // rendered if these were false.
  @observable bool developerMode = true;
  @observable bool useAceThemes = true;
  @observable bool showWipProjectTemplates = true;
  @observable bool chromeOS = true;

  @observable bool noFileFilterMatches = false;

  InputElement _fileFilter;

  SparkPolymerUI.created() : super.created();

  @override
  void enteredView() {
    super.enteredView();

    _fileFilter = getShadowDomElement('#fileFilter');
  }

  void modelReady(SparkModel model) {
    assert(_model == null);
    _model = model;
    refreshFromModel();
    // Changed selection may mean some menu items become disabled.
    // TODO(ussuri): Perhaps listen to more events, e.g. tab switch.
    _model.eventBus.onEvent(BusEventType.FILES_CONTROLLER__SELECTION_CHANGED)
        .listen((_) {
      refreshFromModel();
    });
    _model.eventBus.onEvent(BusEventType.FILES_CONTROLLER__NO_MATCHING_FILES)
        .listen((SimpleBusEvent e) {
      noFileFilterMatches = !e.cancel;
      refreshFromModel();
    });
  }

  void refreshFromModel() {
    // TODO(ussuri): This also could possibly be done using PathObservers.
    developerMode = SparkFlags.developerMode;
    useAceThemes = SparkFlags.useAceThemes;
    showWipProjectTemplates = SparkFlags.showWipProjectTemplates;
    chromeOS = PlatformInfo.isCros;
    deliverChanges();
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

  void onFontSmaller(Event e) {
    e.stopPropagation();
    _model.aceFontManager.dec();
  }

  void onFontLarger(Event e) {
    e.stopPropagation();
    _model.aceFontManager.inc();
  }

  void onSplitterUpdate(CustomEvent e, var detail) {
    _model.onSplitViewUpdate(detail['targetSize']);
  }

  void onResetGit() {
    _model.syncPrefs.removeValue(['git-auth-info', 'git-user-info']);
    _model.setGitSettingsResetDoneVisible(true);
  }

  void onSendFeedback() {
    window.open('https://github.com/dart-lang/spark/issues/new', '_blank');
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

  void fileFilterKeydownHandler(KeyboardEvent e) {
    if (e.keyCode == KeyCode.ESC) {
      _fileFilter.value = '';
      _fileFilter.blur();
      _model.filterFileList(null);
      e..preventDefault()..stopPropagation();
    }
  }

  void fileFilterInputHandler(Event e) {
    _model.filterFileList(_fileFilter.value);
  }
}
