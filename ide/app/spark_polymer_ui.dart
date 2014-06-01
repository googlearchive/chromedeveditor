// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_polymer.ui;

import 'dart:html';

import 'package:polymer/polymer.dart';
import 'package:spark_widgets/common/spark_widget.dart';
import 'package:spark_widgets/spark_split_view/spark_split_view.dart';

import 'spark_flags.dart';
import 'spark_model.dart';
import 'lib/event_bus.dart';
import 'lib/platform_info.dart';

@CustomTag('spark-polymer-ui')
class SparkPolymerUI extends SparkWidget {
  SparkModel _model;

  // Just some value to start with in case the client doesn't provide it on
  // startup.
  @published int splitViewPosition = 100;

  // NOTE: The initial values for these have to be such that dependent
  // <template if> blocks in the .html are turned on, because the app
  // uses [querySelector] upon startup to find elements in those blocks.
  // The values are later set to their actual values in [refreshFromModel].
  @observable bool developerMode = true;
  @observable bool useAceThemes = true;
  @observable bool showWipProjectTemplates = true;
  @observable bool chromeOS = false;

  @observable bool showNoFileFilterMatches = false;

  SparkSplitView _splitView;
  InputElement _fileFilter;

  SparkPolymerUI.created() : super.created();

  @override
  void enteredView() {
    super.enteredView();

    _splitView = $['splitView'];
    _fileFilter = $['fileFilter'];
  }

  void modelReady(SparkModel model) {
    assert(_model == null);
    _model = model;
    // Changed selection may mean some menu items become disabled.
    _model.eventBus.onEvent(BusEventType.FILES_CONTROLLER__SELECTION_CHANGED)
        .listen(refreshFromModel);
    refreshFromModel();
  }

  void refreshFromModel([_]) {
    // TODO(ussuri): This also could possibly be done using PathObservers.
    developerMode = SparkFlags.developerMode;
    useAceThemes = SparkFlags.useAceThemes;
    showWipProjectTemplates = SparkFlags.showWipProjectTemplates;
    chromeOS = PlatformInfo.isCros;

    // This propagates external changes down to the enclosed widgets.
    Observable.dirtyCheck();
  }

  void splitViewPositionChanged() {
    // TODO(ussuri): In deployed code, this was critical for correct
    // propagation of the client's changes in [splitViewPosition] to _splitView.
    // Investigate.
    if (IS_DART2JS) {
      _splitView..targetSize = splitViewPosition..targetSizeChanged();
    }
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

  // TODO(ussuri): Find a better way to achieve this.
  void onResetPreference() {
    Element resultElement = $['preferenceResetResult'];
    resultElement.style.display = 'block';
    resultElement.text = '';
    _model.syncPrefs.clear().then((_) {
      _model.localPrefs.clear();
    }).catchError((e) {
      resultElement.text = 'Error resetting preferences';
    }).then((_) {
      resultElement.text = 'Preferences have been reset - restart Spark';
    });
  }

  void handleAnchorClick(Event e) {
    e..preventDefault()..stopPropagation();
    AnchorElement anchor = e.target;
    window.open(anchor.href, '_blank');
  }

  void fileFilterKeydownHandler(KeyboardEvent e) {
    if (e.keyCode == KeyCode.ESC) {
      e..preventDefault()..stopPropagation();
      _fileFilter.value = '';
      _updateFileFilterActive(false);
      _updateFileFilterNoMatches(false);
      _model.filterFilesList(null);
    }
  }

  void fileFilterInputHandler(Event e) {
    _updateFileFilterActive(_fileFilter.value.isNotEmpty);
    _model.filterFilesList(_fileFilter.value).then((bool matchesFound) {
      _updateFileFilterNoMatches(!matchesFound);
    });
  }

  void _updateFileFilterActive(bool active) {
    _fileFilter.classes.toggle('active', active);
  }

  void _updateFileFilterNoMatches(bool showNoMatchesFound) {
    showNoFileFilterMatches = showNoMatchesFound;
    deliverChanges();
  }
}
