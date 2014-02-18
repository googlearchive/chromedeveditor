// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.selection;

import 'dart:html';

import 'package:polymer/polymer.dart';

import '../common/spark_widget.dart';

// Ported from Polymer Javascript to Dart code.

@CustomTag("spark-selection")
class SparkSelection extends SparkWidget {
  @published bool multi = false;

  final List<Element> _selection = [];

  SparkSelection.created(): super.created();

  dynamic get selection =>
      multi ? _selection : _selection.isNotEmpty ? _selection[0] : null;

  bool isSelected(Element inItem) => _selection.contains(inItem);

  void _setSelected(Element inItem, bool inIsSelected) {
    if (inItem == null) return;

    if (inIsSelected) {
      _selection.add(inItem);
    } else {
      _selection.remove(inItem);
    }

    // TODO(sjmiles): consider replacing with summary notifications (async job).
    asyncFire('select', detail: {'item': inItem, 'isSelected': inIsSelected});
  }

  void select(Element inItem) {
    if (multi) {
      toggle(inItem);
    } else if (selection != inItem) {
      _setSelected(selection, false);
      _setSelected(inItem, true);
    }
  }

  void toggle(Element inItem) {
    _setSelected(inItem, !isSelected(inItem));
  }

  void clear() {
    _selection.clear();
  }
}
