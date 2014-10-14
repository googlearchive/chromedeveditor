// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.dialog;

import 'dart:async';
import 'dart:html';

import 'package:polymer/polymer.dart';

import '../common/spark_widget.dart';
import '../spark_dialog_button/spark_dialog_button.dart';
import '../spark_modal/spark_modal.dart';

@CustomTag('spark-dialog')
class SparkDialog extends SparkWidget {
  // TODO(ussuri): Replace with a regular published property (BUG #2252).
  /**
   * The title of the dialog.
   */
  @published String get headerTitle => _headerTitle;
  @published set headerTitle(String value) {
    _headerTitle = value;
    if (_headerTitleElement != null) _headerTitleElement.text = value;
  }

  /**
   * Do not show the closing X button at top-right corner
   */
  @published bool noClosingX = false;

  /**
   * The kind of animation that the overlay should perform on open/close.
   */
  @published String animation = 'scale-slideup';

  bool _activityVisible = false;

  SparkModal _modal;
  String _headerTitle = '';
  Element _headerTitleElement;
  FormElement _body;
  Element _progress;
  Iterable<SparkDialogButton> _buttons;
  List<_ValidatedField> _validatedFields = [];

  SparkDialog.created() : super.created();

  @override
  void attached() {
    super.attached();

    SparkWidget.enableKeyboardEvents(_modal);

    _modal = $['modal'];
    _headerTitleElement = $['headerTitle'];
    _body = $['body'];
    _buttons = SparkWidget.inlineNestedContentNodes($['buttonsContent']);
    _progress = $['progress'];

    headerTitle = _headerTitle;
    _progress.classes.toggle('hidden', !_activityVisible);

    // Listen to the form's global validity changes. Additional listeners are
    // added below to input fields.
    _body.onChange.listen(_updateFormValidity);
  }

  void show() {
    if (!_modal.opened) {
      _addValidatableFields(
          SparkWidget.inlineNestedContentNodes($['bodyContent']));
      _updateFormValidity();
      _modal.show();
      focus();
    }
  }

  void hide() {
    if (_modal.opened) {
      _validatedFields
          ..forEach((f) => f.cleanup())
          ..clear();
      _modal.hide();
    }
  }

  void handleModalTransitionStart(CustomEvent event, dynamic detail) {
    if (detail['opening']) {
      style.display = 'block';
    }
  }

  void handleModalTransitionEnd(CustomEvent event, dynamic detail) {
    if (!(detail['opened'])) {
      style.display = 'none';
    }
  }

  bool get activityVisible => _activityVisible;

  void set activityVisible(bool visible) {
    _activityVisible = visible;
    _progress.classes.toggle('hidden', !_activityVisible);
  }

  bool isDialogValid() => _validatedFields.every((f) => f.isValid);

  void _addValidatableFields(Iterable<Node> candidates) {
    _validatedFields.clear();
    _addValidatableFieldsImpl(candidates);
  }

  void _addValidatableFieldsImpl(Iterable<Node> candidates) {
    candidates.forEach((Element element) {
      if (element is InputElement) {
        _validatedFields.add(new _ValidatedField(element, _updateFormValidity));
      } else {
        _addValidatableFieldsImpl(element.children);
      }
    });
  }

  void _updateFormValidity([_]) {
    // NOTE: _body.checkValidity() didn't work.
    final bool formIsValid = isDialogValid();
    _buttons.forEach((b) => b.updateParentFormValidity(formIsValid));
  }
}

@reflectable
class _ValidatedField {
  final InputElement _element;
  final Function _onValidityChange;
  MutationObserver _observer;
  List<StreamSubscription> _eventSubs = [];

  // NOTE: [willValidate] takes disablement into account.
  bool get isValid => !_element.willValidate || _element.checkValidity();

  _ValidatedField(this._element, this._onValidityChange) {
    // After a first visit to [_element], start showing its validity state
    // (red border) when it's not focused. Don't show red border while editing
    // to avoid distraction.
    _removeVisited();
    _eventSubs.addAll(
        SparkWidget.addEventHandlers(
            [_element.onFocus, _element.onClick], _addVisited));

    // Listen to editing-related events to update the validity. Just listening
    // to the parent form's [onChange] isn't enough to react to real-time edits.
    _eventSubs.addAll(
        SparkWidget.addEventHandlers(
            [_element.onChange,
             _element.onInput,
             _element.onPaste,
             _element.onReset],
            _updateValidity));

    // Detect programmatic changes to some attributes. Sadly, that doesn't
    // include [value], because [value] is special (not a pure attribute).
    _observer = new MutationObserver((records, _) => _updateValidity(records));
    _observer.observe(
            _element,
            childList: false,
            attributes: true,
            characterData: true,
            subtree: false,
            attributeOldValue: false,
            characterDataOldValue: false);
  }

  void cleanup() {
    SparkWidget.removeEventHandlers(_eventSubs);
  }

  bool _addVisited([_]) => _element.classes.add('visited');

  bool _removeVisited([_]) => _element.classes.remove('visited');

  void _updateValidity([_]) => _onValidityChange();
}
