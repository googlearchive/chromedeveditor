// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.selection;

import 'package:polymer/polymer.dart';

import '../common/spark_widget.dart';

// Ported from Polymer Javascript to Dart code.

@CustomTag("spark-selection")
class SparkSelection extends SparkWidget {
  @published bool multi = false;

  final List _selection = [];

  SparkSelection.created(): super.created();

  void ready() {
    super.ready();
    clear();
  }

  void clear() {
    _selection.clear();
  }

  get selection =>
      multi ? _selection : _selection.isNotEmpty ? _selection[0] : null;

  bool isSelected(inItem) => _selection.contains(inItem);

  void setItemSelected(inItem, inIsSelected) {
    if (inItem != null) {
      if (inIsSelected) {
        _selection.add(inItem);
      } else {
        _selection.remove(inItem);
      }
      // TODO(sjmiles): consider replacing with summary
      // notifications (asynchronous job)
      asyncFire('select', detail: {'isSelected': inIsSelected, 'item': inItem});
    }
  }

  void select(inItem) {
    if (multi) {
      toggle(inItem);
    } else if (selection != inItem) {
      setItemSelected(selection, false);
      setItemSelected(inItem, true);
    }
  }

  void toggle(inItem) {
    setItemSelected(inItem, !isSelected(inItem));
  }
}
