// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_polymer.ui;

import 'dart:html';

import 'package:polymer/polymer.dart';
import 'package:spark_widgets/common/spark_widget.dart';
import 'package:spark_widgets/spark_suggest/spark_suggest_box.dart';

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
  }

  void onMenuSelected(Event event, var detail) {
    final actionId = detail['item'];
    final action = SparkModel.instance.actionManager.getAction(actionId);
    // Action can be null when selecting theme or key menu option.
    if (action != null) {
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
}
