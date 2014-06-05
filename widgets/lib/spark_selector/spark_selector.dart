// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.selector;

import 'dart:html';

import 'package:polymer/polymer.dart';

import '../common/spark_widget.dart';
import '../spark_selection/spark_selection.dart';

/**
 * Sets and tracks selected element(s) in a list.
 *
 * Default is to use the index of the item element.
 *
 * If you want a specific attribute value of the element to be
 * used instead of index, set "valueAttr" to that attribute name.
 *
 * Example:
 *
 *     <polymer-selector valueAttr="label" selected="foo">
 *       <div label="foo"></div>
 *       <div label="bar"></div>
 *       <div label="zot"></div>
 *     </polymer-selector>
 *
 * In multi-selection this should be an array of values.
 *
 * Example:
 *
 *     <polymer-selector id="selector" valueAttr="label" multi>
 *       <div label="foo"></div>
 *       <div label="bar"></div>
 *       <div label="zot"></div>
 *     </polymer-selector>
 *
 *     ($['selector'] as SparkSelector).selected = ['foo', 'zot'];
 */
@CustomTag("spark-selector")
class SparkSelector extends SparkWidget {
  /// If true, multiple selections are allowed.
  @published bool multi = false;

  /// The IDs of the initially selected element ([multi]==false) or
  /// a space-separated list of the initially selected elements
  /// ([multi]==true). An ID can be either the element's 0-based index or
  /// the element's value as determined by the [valueAttr] property.
  /// [selected] can also be externally set after the initial instantiation
  /// to force a particular selection.
  @published dynamic inSelection;

  /// The attribute to be used as an item's "value".
  @published String valueAttr;

  /// The CSS selector to choose the selectable subset of elements passed from
  /// the light DOM into the <content> insertion point.
  @published String itemFilter = '*';

  /// The CSS class to add to an active element (hovered/selected via keyboard).
  @published String activeClass = '';
  /// The attribute to add to an active element (hovered/selected via keyboard).
  @published String activeAttr = '';
  /// The CSS class to add to a selected element.
  @published String selectedClass = '';
  /// The attribute to set on a selected element.
  @published String selectedAttr = '';

  SparkSelection selection;

  List<Element> _cachedItems;
  Element _active;
  bool _fireEvents = true;

  static final Map<int, int> _keyNavigationDistances = {
    KeyCode.UP: -1,
    KeyCode.DOWN: 1,
    KeyCode.PAGE_UP: -10,
    KeyCode.PAGE_DOWN: 10
  };

  SparkSelector.created() : super.created();

  @override
  void enteredView() {
    super.enteredView();

    selection = $['selection'];

    // TODO(terry): Should be onTap when PointerEvents are supported.
    onMouseOver.listen(mouseOverHandler);
    onClick.listen(clickHandler);
    onKeyDown.listen(keyDownHandler);

    // Observe external changes to the lightDOM items inserted in our <content>.
    new MutationObserver((m, o) => _onNewItems())
        .observe(this, childList: true);
  }

  void _onNewItems() {
    // TODO(ussuri): Assigning _items here directly is premature: if the list
    // contains some <template if=...> for example, the inner contens of the
    // template will not be expanded at this point - that happens later.
    // So instead we mark items as dirty and compute them on first access.
    // Figure out: what's the exactly right moment to compute items.
    _cachedItems = null;
  }

  List<Element> get _items {
    if (_cachedItems == null) {
      _cachedItems =
          SparkWidget.inlineNestedContentNodes($['items'])
              .where((Element item) => item.matches(itemFilter))
                  .toList();
    }
    return _cachedItems;
  }

  void resetState() {
    _initSelection();
    _setActive(null);
  }

  void inSelectionChanged() {
    _initSelection();
  }

  void _initSelection() {
    // TODO(ussuri): Initial selection doesn't work e.g. in spark-suggest-box:
    // the dropdown appears, the items get selected briefly, then the dropdown
    // closes.
    List<String> s;
    if (multi) {
      s = (inSelection == null) ? [] :
          (inSelection is List<String>) ? inSelection :
          (inSelection is String) ? (inSelection as String).split(" ") :
          (inSelection is int) ? [(inSelection as int).toString()] : null;
    } else {
      s = (inSelection == null) ? [] :
          (inSelection is String) ? [inSelection] :
          (inSelection is int) ? [(inSelection as int).toString()] : null;
    }
    assert(s != null);
    _fireEvents = false;
    selection.init(s.toSet());
    _fireEvents = true;
  }

  /// Find an item with valueAttr == value and return it's index.
  Element _valueToItem(String value) {
    Element item = _items.firstWhere(
        (i) => _itemToValue(i) == value, orElse: () => null);
    if (item == null) {
      // If no item found, the value itself might be the index:
      final int idx = int.parse(value, onError: (_) => -1);
      if (idx >= 0 && idx < _items.length) {
        item = _items[idx];
      }
    }
    return item;
  }

  /// Extract the value for an item if [valueAttr] is set, or else its index.
  String _itemToValue(Element item) {
    return valueAttr != null ?
        item.attributes[valueAttr] : _items.indexOf(item).toString();
  }

  /// Events fired from <polymer-selection> object.
  void selectionSelectHandler(CustomEvent e, var detail) {
    e.stopPropagation();

    final Element item = _valueToItem(detail['value']);
    if (item != null) {
      _renderSelected(item, detail['isSelected']);

      if (_fireEvents) {
        asyncFire('activate', detail: detail, canBubble: true);
      }
    }
  }

  // Events fired for menu elements when hovered over.
  void mouseOverHandler(MouseEvent e) {
    final Element target = e.target;
    if (_items.contains(target)) {
      _setActive(target);
    }
  }

  // Event fired from host.
  void clickHandler(MouseEvent e) {
    if (_active.contains(e.target)) {
      _commitActiveToSelected();
    } else {
      // This will happen if the user clicks on some element not designated as
      // an item via [itemFilter], e.g. on a menu separator.
      assert(!_items.contains(e.target));
    }
  }

  void keyDownHandler(KeyboardEvent e) {
    maybeHandleKeyStroke(e.keyCode);
  }

  /// This is supposed to be called by an embedder of spark-selector to give
  /// it a chance to handle keyboard-driven navigation between items and commit
  /// currently active item to the selection. In the last case, the embedder
  /// should expect to receive one or more 'activate' events.
  /// One example is spark-suggest-box, which maintains its text box focused to
  /// handle input, but wants the dropdown list of suggestions to handle
  /// navigation and selection on arrows and ENTER.
  bool maybeHandleKeyStroke(int keyCode) {
    final dist = _keyNavigationDistances[keyCode];
    if (dist != null) {
      _moveActive(dist);
      return true;
    }
    if (keyCode == KeyCode.ENTER) {
      _commitActiveToSelected();
    }
    return false;
  }

  void _setActive(Element newActive) {
    // TODO(ussuri): Figure out correct interaction with [selectedStyle] when
    // [selectedStyle]==[activeStyle].
    _renderActive(_active, false);
    _renderActive(newActive, true);
    if (newActive != null) {
      newActive.scrollIntoView(ScrollAlignment.CENTER);
    }
    _active = newActive;
  }

  void _moveActive(int distance) {
    if (_items.isEmpty) return;

    int activeIdx = _items.indexOf(_active);
    if (activeIdx == -1) {
      activeIdx = distance > 0 ? -1 : _items.length;
    }
    activeIdx = (activeIdx + distance).clamp(0, _items.length - 1);
    _setActive(_items[activeIdx]);
  }

  /// Add the currently active item, if any, to the current selection.
  void _commitActiveToSelected() {
    if (_active != null) {
      // [selection] will trigger 0 or more [selectionSelectHandler] calls
      // in response to this, depending on which items become newly selected
      // and which become deselected, in corresponance with the [multi] logic.
      selection.select(_itemToValue(_active));
    }
  }

  void _renderSelected(Element item, bool isSelected) =>
      _renderClassAndProperty(item, isSelected, selectedClass, selectedAttr);

  void _renderActive(Element item, bool isActive) =>
      _renderClassAndProperty(item, isActive, activeClass, activeAttr);

  static void _renderClassAndProperty(
      Element item, bool isOn, String cssClass, String attr) {
    if (item != null) {
      if (cssClass != null && cssClass.isNotEmpty) {
        item.classes.toggle(cssClass, isOn);
      }
      if (attr != null && attr.isNotEmpty) {
        if (isOn) {
          item.attributes[attr] = '';
        } else {
          item.attributes.remove(attr);
        }
      }
    }
  }
}
