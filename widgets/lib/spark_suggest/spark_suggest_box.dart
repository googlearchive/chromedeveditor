// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.suggest;

import 'dart:async';
import 'dart:html';

import 'package:polymer/polymer.dart';

import 'package:spark_widgets/common/spark_widget.dart';
import 'package:spark_widgets/spark_menu/spark_menu.dart';
import 'package:spark_widgets/spark_overlay/spark_overlay.dart';

/**
 * A single suggestion supplied by a [SuggestOracle]. Provides a [label]
 * and an [onSelected] callback. [onSelected] is called when the user chooses
 * `this` suggestion.
 */
@reflectable
class Suggestion {
  final String label;
  final String details;

  final Function onSelected;

  Suggestion(this.label, {this.details, this.onSelected});

  String get formatDetails => details != null ? "[$details]" : "";

  set formatDetails(String v) => print("WHY? details=$v");
  set label(String v) => print("WHY? label=$v");
}

/**
 * Source suggestions for spark-suggest-box. Implemented and supplied by the
 * component implementing a concrete suggest box.
 */
abstract class SuggestOracle {
  /**
   * [SparkSuggestBox] will call this method with [text] entered by user and
   * listen on returned [Stream] for suggestions. The stream may return
   * suggestions multiple times. This way if the suggestions are coming from
   * multiple sources they can be supplied incrementally. While the stream is
   * open the suggest-box will show a loading indicator as a cue for the user
   * that more suggestions may be received. It is up to the implementor to
   * close the stream after delivering all suggestions.
   */
  Stream<List<Suggestion>> getSuggestions(String text);
}

/**
 * A suggest component. See docs in `spark_suggest_box.html`.
 */
@CustomTag("spark-suggest-box")
class SparkSuggestBox extends SparkWidget {
  /// Text shown when the text box is empty.
  @published String placeholder;
  /// Provies suggestions for `this` suggest box.
  @published SuggestOracle oracle;
  /// Open state of the overlay.
  @published bool opened = false;

  /// Currently displayed suggestions.
  @observable final suggestions = new ObservableList();

  StreamSubscription _oracleSub;

  SparkSuggestBox.created() : super.created();

  @override
  void enteredView() {
    super.enteredView();
    _textBox = $['text-box'];
  }

  InputElement _textBox;

  /// Shows the suggestion list popup with the given suggestions.
  void _showSuggestions(List<Suggestion> update) {
    suggestions.clear();
    suggestions.addAll(update);
    toggle(true);
    shadowRoot.querySelectorAll('.unresolved').forEach((Element e) {
      print(e);
      e.classes.remove('unresolved');
    });
  }

  /// Hides the suggestion list popup and clears the suggestion list.
  void _hideSuggestions() {
    suggestions.clear();
    toggle(false);
  }

  inputKeyUp(KeyboardEvent e) {
    if (e.keyCode == SparkWidget.DOWN_KEY ||
        e.keyCode == SparkWidget.UP_KEY ||
        e.keyCode == SparkWidget.ENTER_KEY) {
      if (!opened) {
        suggest();
      }
    } else if (e.keyCode == SparkWidget.ESCAPE_KEY) {
    } else {
      suggest();
    }
  }

  void inputFocus() {
    if (_textBox.value.length != 0) {
      suggest();
    }
  }

  void suggest() {
    _cleanupSubscriptions();
    _oracleSub = oracle.getSuggestions(_textBox.value)
        .listen((List<Suggestion> update) {
          if (update != null && update.isNotEmpty) {
            _showSuggestions(update);
          } else {
            _hideSuggestions();
          }
        }, onDone: _cleanupSubscriptions);
  }

  void _cleanupSubscriptions() {
    if (_oracleSub != null) {
      _oracleSub.cancel();
      _oracleSub = null;
    }
  }

  //* Toggle the opened state of the dropdown.
  void toggle([bool inOpened]) {
    final oldOpened = opened;
    opened = inOpened != null ? inOpened : !opened;
    if (opened != oldOpened) {
      ($['suggestion-list-menu'] as SparkMenu).clearSelection();
      // TODO(ussuri): A temporary plug to make spark-overlay see changes
      // in 'opened' when run as deployed code. Just binding via {{opened}}
      // alone isn't detected and the menu doesn't open.
      if (IS_DART2JS) {
        ($['suggestion-list-overlay'] as SparkOverlay).opened = opened;
      }
    }
  }

  //* Handle the on-opened event from the dropdown. It will be fired e.g. when
  //* mouse is clicked outside the dropdown (with autoClosedDisabled == false).
  void onOpened(CustomEvent e) {
    // Autoclosing is the only event we're interested in.
    if (e.detail == false) {
      opened = false;
    }
  }

  void onSelected(Event event, var detail) {
    print(detail);
  }
}
