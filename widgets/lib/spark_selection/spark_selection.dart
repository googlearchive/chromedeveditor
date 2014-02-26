// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.selection;

import 'package:polymer/polymer.dart';

import '../common/spark_widget.dart';

@CustomTag("spark-selection")
class SparkSelection extends SparkWidget {
  @published bool multi = false;

  final Set<dynamic> _selection = new Set<dynamic>();

  SparkSelection.created(): super.created();

  dynamic get selection =>
      multi ? _selection : _selection.isNotEmpty ? _selection.single : null;

  bool isSelected(var value) => _selection.contains(value);

  void _setSelected(var value, bool isSelected) {
    if (value == null) return;

    if (isSelected) {
      _selection.add(value);
    } else {
      _selection.remove(value);
    }

    // TODO(sjmiles): consider replacing with summary notifications (async job).
    asyncFire('select', detail: {'value': value, 'isSelected': isSelected});
  }

  void init(Set<dynamic> values) {
    assert(multi || values.length <= 1);
    // Unselect values that are currently in [_selection] but not in [values].
    _selection.difference(values).forEach((v) => _setSelected(v, false));
    // Select values that are in [values] but not currently in [_selection].
    values.difference(_selection).forEach((v) => _setSelected(v, true));
  }

  void select(var value) {
    if (multi) {
      toggle(value);
    } else if (selection != value) {
      _setSelected(selection, false);
      _setSelected(value, true);
    }
  }

  void toggle(var value) {
    assert(multi);
    _setSelected(value, !isSelected(value));
  }

  void clear() {
    // NOTE: This is necessary so that events fire for all the removed values.
    while (_selection.isNotEmpty) {
      _setSelected(_selection.first, false);
    }
  }
}
