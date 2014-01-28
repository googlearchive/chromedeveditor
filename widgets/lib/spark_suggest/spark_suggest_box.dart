// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.suggest;

import 'dart:async';
import 'dart:html';

import 'package:polymer/polymer.dart';

import '../common/spark_widget.dart';

/**
 * A single suggestion supplied by a [SuggestOracle]. Provides a [displayLabel]
 * and an [onSelected] callback. [onSelected] is called when the user chooses
 * `this` suggestion.
 */
class Suggestion {
  final String displayLabel;
  final Function onSelected;

  Suggestion(this.displayLabel, {this.onSelected});
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
  /// Currently displayed suggestions.
  @observable final suggestions = new ObservableList();
  /// Currently highlighted (but not yet selected) suggestion
  @observable int selectionIndex = -1;
  /// Whether we're loading suggestions. `true` as long as we're subscribed to
  /// the [oracle].
  @observable bool isLoading;
  /// Is the suggestion list popup visible?
  @observable bool suggestionsOpened = false;

  StreamSubscription _oracleSub;

  SparkSuggestBox.created() : super.created();

  /// Shows the suggestion list popup with the given suggestions.
  void _showSuggestions(List<Suggestion> update) {
    suggestions.clear();
    suggestions.addAll(update);
    selectionIndex = 0;
    suggestionsOpened = true;
  }

  /// Hides the suggestion list popup and clears the suggestion list.
  void _hideSuggestions() {
    suggestions.clear();
    selectionIndex = -1;
    suggestionsOpened = false;
  }

  inputKeyUp(KeyboardEvent e) {
    if (e.keyCode == SparkWidget.DOWN_KEY) {
      if (suggestionsOpened) {
        // List of suggestions already visible. Simply advance the selection.
        selectionIndex++;
        _clampSelectionIndex();
      } else {
        // Look for suggestions
        suggest();
      }
    } else if (e.keyCode == SparkWidget.UP_KEY) {
      selectionIndex--;
      _clampSelectionIndex();
    } else if (e.keyCode == SparkWidget.ENTER_KEY) {
      if (suggestionsOpened && selectionIndex > -1) {
        _selectSuggestion(selectionIndex);
      } else {
        suggest();
      }
    } else if (e.keyCode == SparkWidget.ESCAPE_KEY) {
      _hideSuggestions();
    } else {
      suggest();
    }
  }

  void inputFocus() {
    InputElement textBox = $['text-box'];
    if (textBox.value.length == 0) {
      return;
    }

    suggest();
  }

  void suggest() {
    InputElement textBox = $['text-box'];
    _cleanupSubscriptions();
    isLoading = true;
    _oracleSub = oracle.getSuggestions(textBox.value)
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
      isLoading = false;
    }
  }

  int _itemIndexForEvent(Event evt) {
    Element itemDiv = evt.currentTarget;
    return int.parse(itemDiv.attributes['item-index']);
  }

  void _selectSuggestion(int index) {
    suggestions[index].onSelected();
    _hideSuggestions();
  }

  void mouseOverItem(MouseEvent evt) {
    selectionIndex = _itemIndexForEvent(evt);
  }

  void mouseClickedItem(MouseEvent evt) {
    _selectSuggestion(_itemIndexForEvent(evt));
  }

  void _clampSelectionIndex() {
    if (selectionIndex < -1) {
      selectionIndex = -1;
    } else if (selectionIndex > suggestions.length - 1) {
      selectionIndex = suggestions.length - 1;
    }
  }
}
