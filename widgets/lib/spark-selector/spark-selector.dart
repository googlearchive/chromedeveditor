// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.selector;

import 'dart:html' show MutationRecord, MutationObserver, Node, Element;

import 'package:polymer/polymer.dart';
import "package:template_binding/template_binding.dart" show nodeBind;

import '../spark-selection/spark-selection.dart';

// Ported from Polymer Javascript to Dart code.

/**
 * Gets or sets the selected element.  Default to use the index
 * of the item element.
 *
 * If you want a specific attribute value of the element to be
 * used instead of index, set "valueattr" to that attribute name.
 *
 * Example:
 *
 *     <polymer-selector valueattr="label" selected="foo">
 *       <div label="foo"></div>
 *       <div label="bar"></div>
 *       <div label="zot"></div>
 *     </polymer-selector>
 *
 * In multi-selection this should be an array of values.
 *
 * Example:
 *
 *     <polymer-selector id="selector" valueattr="label" multi>
 *       <div label="foo"></div>
 *       <div label="bar"></div>
 *       <div label="zot"></div>
 *     </polymer-selector>
 *
 *     this.$.selector.selected = ['foo', 'zot'];
 */
@CustomTag("spark-selector")
class SparkSelector extends SparkSelection {
  @published dynamic selected = null;

  /// If true, multiple selections are allowed.
  @published bool multi = false;

  /// Specifies the attribute to be used for "selected" attribute.
  @published String valueattr = 'name';

  /// Specifies the CSS class to be used to add to the selected element.
  @published String selectedClass = 'selected';

  /// Specifies the property to be used to set on the selected element.
  @published String selectedProperty = 'active';

  /* Returns the currently selected element. In multi-selection this returns
   * an array of selected elements.
   */
  // TODO(terry): If marked as @observable bad crash think stack overflow?
  @published dynamic selectedItem = null;

  /* The target element that contains items.  If this is not set
   * polymer-selector is the container.
   */
  @published Element target = null;

  @published String itemsSelector = null;

  // TODO(terry): Should be tap when PointerEvents are supported.
  @published String activateEvent = 'click';

  @published bool notap = false;

  @published dynamic selectedModel = null;

  MutationObserver _observer;

  SparkSelector.created(): super.created();

  @override
  void enteredView() {
    super.enteredView();

    _observer = new MutationObserver(_onMutation);
    if (target == null) {
      target = this;
    }
    updateSelected();
  }

  void _onMutation(List<MutationRecord> mutations, MutationObserver observer) {
    updateSelected();
  }

  List<Element> get items {
    assert(target == null);
    List<Element> nodes = null;
    if (target == this) {
      nodes = ($['items'] as dynamic).getDistributedNodes();
    } else if (itemsSelector != null) {
      nodes = (target as dynamic).querySelectorAll(itemsSelector);
    } else {
      nodes = (target as dynamic).children;
    }
    return nodes.where((node) => node.localName != "template")
        .toList(growable: false);
  }

  void targetChanged(old) {
    if (old != null) {
      removeListener(old);
      _observer.disconnect();
    }
    if (target != null) {
      addListener(target);
      _observer.observe(target, childList: true, subtree: true);
    }
  }

  void addListener(Node node) {
    node.addEventListener(activateEvent, activateHandler);
  }

  void removeListener(node) {
    node.removeEventListener(activateEvent, activateHandler);
  }

  get selection => ($['selection'] as dynamic).selection;

  void selectedChanged() {
    this.updateSelected();
  }

  void updateSelected() {
    validateSelected();
    if (multi) {
      clearSelection();
      for (var s in selected) {
        valueToSelection(s);
      }
    } else {
      valueToSelection(selected);
    }
  }

  void validateSelected() {
    if (multi && selected is List) {
      // TODO(ussuri): What does this achieve?
      selected = selected;
    }
  }

  void clearSelection() {
    var foundSelection = $['selection'];
    if (multi) {
      var selections = selection;
      for (var s in selections) {
        foundSelection.setItemSelected(s, false);
      };
    } else {
      foundSelection.setItemSelected(selection, false);
    }
    selectedItem = null;
    foundSelection.clear();
  }

  void valueToSelection(value) {
    final index = valueToIndex(value);
    if (index < items.length) {
      var item = items[index];
      ($['selection'] as dynamic).select(item);
    }
  }

  void updateSelectedItem() {
    selectedItem = selection;
  }

  void selectedItemChanged() {
    if (selectedItem != null) {
      var s = (selectedItem is List) ? selectedItem[0] : selectedItem;
      var t = nodeBind(s).templateInstance;
      selectedModel = t != null ? t.model : null;
    } else {
      selectedModel = null;
    }
  }

  int valueToIndex(var value) {
    var allItems = items;
    // find an item with value == value and return it's index
    for (var i = 0; i < allItems.length; i++) {
      var c = allItems[i];
      if (valueForNode(c) == value) {
        return i;
      }
    }
    // if no item found, the value itself is probably the index
    return (value is num) ? value : int.parse(value);
  }

  String valueForNode(Element node) =>
      node.attributes.containsKey(valueattr) ? node.attributes[valueattr] : "";

  // events fired from <polymer-selection> object
  void selectionSelect(e, detail) {
    updateSelectedItem();
    var detailItem = detail['item'];
    if (detailItem != null) {
      this.applySelection(detailItem, detail['isSelected']);
    }
  }

  void applySelection(Element item, bool isSelected) {
    if (selectedClass.isNotEmpty) {
      item.classes.toggle(selectedClass);
    }
    if (selectedProperty.isNotEmpty) {
      item.classes.add(selectedProperty);
    }
  }

  // event fired from host
  activateHandler(e) {
    if (!notap) {
      var i = findDistributedTarget(e.target, items);
      if (i >= 0) {
        var item = items[i];
        var selectByName = valueForNode(item);
        // By name or by id.
        var s = selectByName.isNotEmpty ? selectByName : i;
        if (multi) {
          if (selected != null) {
            addRemoveSelected(s);
          } else {
            selected = [s];
          }
        } else {
          selected = s;
        }
        asyncFire('activate', detail: {'item': item}, canBubble: true);
      }
    }
  }

  void addRemoveSelected(value) {
    var i = selected.indexOf(value);
    if (i >= 0) {
      selected.remove(i);
    } else {
      selected.add(value);
    }
    valueToSelection(value);
  }

  /// Find first ancestor of target (including itself) in nodes.
  int findDistributedTarget(target, List nodes) => nodes.indexOf(target);
}
