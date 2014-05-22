// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.suggest_box;

import 'dart:async';
import 'dart:html';

import 'package:polymer/polymer.dart';

import '../common/spark_widget.dart';
import '../spark_selector/spark_selector.dart';
import '../spark_overlay/spark_overlay.dart';

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
  @observable final suggestions = new ObservableList<Suggestion>();

  InputElement _textBox;
  SparkOverlay _overlay;
  SparkSelector _menu;

  StreamSubscription _oracleSub;

  SparkSuggestBox.created() : super.created();

  @override
  void enteredView() {
    super.enteredView();

    _textBox = $['textBox'];
    _overlay = $['suggestionListOverlay'];
    _menu = $['suggestionListMenu'];
  }

  /**
   *  Shows the suggestion list popup with the given suggestions.
   */
  void _showSuggestions(List<Suggestion> update) {
    suggestions.clear();
    suggestions.addAll(update);
    toggle(true);
  }

  /**
   *  Hides the suggestion list popup and clears the suggestion list.
   */
  void _hideSuggestions() {
    toggle(false);
  }

  /**
   *  Handles non-printable character keys entered in the text box.
   */
  void textBoxKeyDownHandler(KeyboardEvent e) {
    bool stopPropagation = true;

    // Redirect the key stroke to the menu for possible action, e.g. moving
    // the active element up or down, or comitting it to selection.
    if (_menu.maybeHandleKeyStroke(e.keyCode)) {
      e.preventDefault();
    }

    switch (e.keyCode) {
      case KeyCode.DOWN:
      case KeyCode.UP:
      case KeyCode.PAGE_UP:
      case KeyCode.PAGE_DOWN:
        if (!opened) {
          _suggest();
        }
        break;
      case KeyCode.ENTER:
        if (!opened) {
          _suggest();
        } else {
          // TODO(ussuri): Should probably call _input.blur() here, but that
          // triggers [inputOnBlurHandler], which interferes with pending
          // [menuActivateHandler] resulting from [maybeHandleKeyStroke] call.
        }
        break;
      case KeyCode.ESC:
        _hideSuggestions();
        break;
      default:
        // Allow all other keys such as F10 to bubble up for handling.
        stopPropagation = false;
        break;
    }

    if (stopPropagation) {
      e.stopPropagation();
    }
  }

  /**
   *  Handles printable character keys entered in the text box.
   */
  void textBoxInputHandler(Event e) {
    // NOTE: Don't preventDefault to get the character entered in the textbox.
    e.stopImmediatePropagation();
    _suggest();
  }

  /**
   * Handle click, focus and blur events in the text box.
   */
  void textBoxClickHandler(MouseEvent e) {
    // NOTE: Don't preventDefault to get the cursor repositioned in the textbox.
    e.stopImmediatePropagation();
    if (!opened && _textBox.value.isNotEmpty) {
      _suggest();
    }
  }

  void textBoxFocusHandler(FocusEvent e) {
    e.stopImmediatePropagation();
    if (_textBox.value.isNotEmpty) {
      _suggest();
    }
  }

  void textBoxBlurHandler(FocusEvent e) {
    e.stopImmediatePropagation();
    _hideSuggestions();
  }

  /**
   * Re-gets suggestions from the oracle based on the updated text box value
   * and opens the dropdown to display them, if there are any.
   */
  void _suggest() {
    void cleanupSubscriptions() {
      if (_oracleSub != null) {
        _oracleSub.cancel();
        _oracleSub = null;
      }
    }

    cleanupSubscriptions();
    _oracleSub = oracle.getSuggestions(_textBox.value)
        .listen((List<Suggestion> update) {
          if (update != null && update.isNotEmpty) {
            _showSuggestions(update);
          } else {
            _hideSuggestions();
          }
        }, onDone: cleanupSubscriptions);
  }

  /**
   *  Toggle the opened state of the dropdown.
   */
  void toggle([bool inOpened]) {
    final bool newOpened = inOpened != null ? inOpened : !opened;
    if (newOpened != opened) {
      opened = newOpened;
      // TODO(ussuri): A temporary plug to make spark-overlay see changes
      // in 'opened' when run as deployed code. Just binding via {{opened}}
      // alone isn't detected and the menu doesn't open. Also, try
      // _overlay.deliverChanges() instead.
      if (IS_DART2JS) {
        _overlay.opened = opened;
      }
      if (opened) {
        focus();
        _menu.resetState();
      }
    }
  }

  /**
   * Handle the on-opened event from the dropdown. It will be fired e.g. when
   * mouse is clicked outside the dropdown (with [autoClose]).
   */
  void overlayOpenedHandler(CustomEvent e) {
    // Autoclosing is the only event we're interested in.
    if (e.detail == false) {
      _hideSuggestions();
    }
  }

  /**
   *  Handle the 'activate' events from the menu.
   */
  void menuActivateHandler(Event event, var detail) {
    if (detail['isSelected']) {
      final int idx = int.parse(detail['value']);
      suggestions[idx].onSelected();

      _hideSuggestions();
    }
  }
}
