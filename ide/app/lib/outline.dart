// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.outline;

import 'dart:async';
import 'dart:html' as html;

import 'enum.dart';
import 'services.dart' as services;
import 'preferences.dart';

class OffsetRange {
  int top;
  int bottom;
  int get center => (top + bottom) ~/ 2;

  OffsetRange([this.top = 0, this.bottom = 0]);

  bool centeredSame(OffsetRange another) => center == another.center;
  bool centeredHigher(OffsetRange another) => top < another.top;
  bool centeredLower(OffsetRange another) => bottom > another.bottom;

  bool includes(int offset) => offset >= top && offset <= bottom;
  bool intersects(OffsetRange another) =>
      !(bottom < another.top || top > another.bottom);

  String toString() => "($top, $bottom)";
}

class _ScrollDirection extends Enum<html.ScrollAlignment> {
  const _ScrollDirection._(html.ScrollAlignment val) : super(val);

  String get enumName => '_ScrollDirection';

  static const UP = const _ScrollDirection._(html.ScrollAlignment.TOP);
  static const DOWN = const _ScrollDirection._(html.ScrollAlignment.BOTTOM);
}

/**
 * Defines a class to build an outline UI for a given block of code.
 */
class Outline {
  List<OutlineItem> _outlineItems;
  OutlineItem _selectedItem;
  OffsetRange _lastScrolledOffsetRange = new OffsetRange();

  html.Element _container;
  html.DivElement _outlineDiv;
  html.DivElement _rootListDiv;
  html.UListElement _rootList;
  html.Element _outlineButton;

  final PreferenceStore _prefs;
  bool _visible = true;

  services.AnalyzerService _analyzer;

  StreamController<OutlineItem> _childSelectedController = new StreamController();

  Outline(this._analyzer, this._container, this._prefs) {
    _outlineDiv = html.querySelector('#outlineContainer');
    _outlineDiv.onMouseWheel.listen((html.MouseEvent event) =>
        event.stopPropagation());
    _rootListDiv = _outlineDiv.querySelector('#outline');
    _rootList = _rootListDiv.querySelector('ul');
    _outlineButton = html.querySelector('#toggleOutlineButton');
    _outlineButton.onClick.listen((e) => toggle());

    _prefs.getValue('OutlineCollapsed').then((String data) {
      if (data == 'true') {
        _outlineDiv.classes.add('collapsed');
      }
    });
  }

  Stream<OutlineItem> get onChildSelected => _childSelectedController.stream;

  Stream get onScroll => _rootListDiv.onScroll;

  OffsetRange get scrollPosition => _lastScrolledOffsetRange;
  void set scrollPosition(OffsetRange offsetRange) {
    if (_outlineItems == null) {
      // If the outline has not been built yet, just save the position
      _lastScrolledOffsetRange = offsetRange;
    }
    scrollOffsetRangeIntoView(offsetRange);
  }

  bool get visible => _visible;
  set visible(bool value) {
    _visible = value;
    _outlineDiv.classes.toggle('hidden', !_visible);
    _outlineButton.classes.toggle('hidden', !_visible);
  }

  bool get showing => _visible && !_outlineDiv.classes.contains('collapsed');

  /**
   * Builds or rebuilds the outline UI based on the given String of code.
   */
  Future build(String name, String code) {
    return _analyzer.getOutlineFor(code, name).then((services.Outline model) {
      _populate(model);
    });
  }

  void _populate(services.Outline outline) {
    _outlineItems = [];
    _rootList.children.clear();

    for (services.OutlineTopLevelEntry data in outline.entries) {
      _create(data);
    }

    scrollOffsetRangeIntoView(_lastScrolledOffsetRange, _ScrollDirection.DOWN);
  }

  OutlineTopLevelItem _create(services.OutlineTopLevelEntry data) {
    if (data is services.OutlineClass) {
      return _addClass(data);
    } else if (data is services.OutlineTopLevelVariable) {
      return _addVariable(data);
    } else if (data is services.OutlineTopLevelFunction) {
      return _addFunction(data);
    } else if (data is services.OutlineTopLevelAccessor) {
      return _addAccessor(data);
    } else if (data is services.OutlineTypeDef) {
      return _addTypeDef(data);
    } else {
      throw new UnimplementedError("Unknown type");
    }
  }

  /**
   * Toggles visibility of the outline.
   */
  void toggle() {
    _outlineDiv.classes.toggle('collapsed');
    String value = _outlineDiv.classes.contains('collapsed') ? 'true' : 'false';
    _prefs.setValue('OutlineCollapsed', value);
  }

  OutlineItem _addItem(OutlineItem item) {
    // Add leaf items to be used to find a position in the outline to scroll to
    // when the file in the editor is scrolled.
    _outlineItems.add(item);
    if (item is OutlineClass) {
      for (OutlineClassMember member in item.members) {
        _outlineItems.add(member);
      }
    }

    // Add [Element]s to the root [Element]. These are different from the above:
    // they are top-level elements that may contain children matching the above.
    _rootList.append(item.element);
    // Listen to 'select' custom events on the element or one of its children.
    item.element.on['selected'].listen((event) =>
        _childSelectedController.add(event.detail));

    return item;
  }

  OutlineTopLevelVariable _addVariable(services.OutlineTopLevelVariable data) =>
      _addItem(new OutlineTopLevelVariable(data));

  OutlineTopLevelFunction _addFunction(services.OutlineTopLevelFunction data) =>
      _addItem(new OutlineTopLevelFunction(data));

  OutlineTopLevelAccessor _addAccessor(services.OutlineTopLevelAccessor data) =>
      _addItem(new OutlineTopLevelAccessor(data));

  OutlineTypeDef _addTypeDef(services.OutlineTypeDef data) =>
      _addItem(new OutlineTypeDef(data));

  OutlineClass _addClass(services.OutlineClass data) =>
      _addItem(new OutlineClass(data));

  OutlineItem get selectedItem => _selectedItem;

  void setSelected(OutlineItem item) {
    if (_selectedItem != null) {
      _selectedItem.setSelected(false);
    }

    _selectedItem = item;

    if (_selectedItem != null) {
      _selectedItem.setSelected(true);
      _selectedItem.scrollIntoView();
    }
  }

  void selectItemAtOffset(int cursorOffset) {
    OutlineItem itemAtCursor = _itemAtCodeOffset(cursorOffset);
    if (itemAtCursor != null) {
      setSelected(itemAtCursor);
    }
  }

  void scrollOffsetRangeIntoView(
      OffsetRange offsetRange, [_ScrollDirection direction]) {
    if (direction != null) {
      // Direction overridden by the caller.
    } else if (offsetRange.centeredLower(_lastScrolledOffsetRange)) {
      direction = _ScrollDirection.DOWN;
    } else if (offsetRange.centeredHigher(_lastScrolledOffsetRange)) {
      direction = _ScrollDirection.UP;
    } else {
      // Direction not specified by the client and we haven't scrolled
      // far enough from previous position.
    }

    if (direction != null) {
      OutlineItem item = _edgeItemInCodeOffsetRange(
          offsetRange, atBottom: direction == _ScrollDirection.DOWN);
      _scrollItemIntoView(item, direction);
      _lastScrolledOffsetRange = offsetRange;
    }
  }

  void _scrollItemIntoView(OutlineItem item, _ScrollDirection direction) {
    if (item == null) return;

    // This may change dynamically: do not cache.
    html.Rectangle rootListRect = _rootListDiv.getBoundingClientRect();
    html.Rectangle elementRect = item.element.getBoundingClientRect();
    // Perhaps the item is already in view.
    if (!rootListRect.containsRectangle(elementRect)) {
      // Use [item.anchor], not [item.element] to pull the minimal amount of
      // [item] into view. For example, [item.element] for OutlineClass
      // spans the whole class, which may not even fit into the viewport.
      item.anchor.scrollIntoView(direction.value);
    }
  }

  OutlineItem _itemAtCodeOffset(int codeOffset) {
    if (_outlineItems == null) return null;

    for (OutlineItem item in _outlineItems) {
      // The first condition will work when the cursor is within an item.
      // The second one will work when the cursor is between items:
      // it will find the first element lower then the offset. It is only
      // needed here because this function is called when the user clicks
      // in the file somewhere: contrast this with [_edgeItemInCodeOffsetRange].
      if (item.offsetRange.includes(codeOffset) ||
          item.offsetRange.top > codeOffset) {
        return item;
      }
    }
    return null;
  }

  OutlineItem _edgeItemInCodeOffsetRange(
      OffsetRange codeOffsetRange, {bool atBottom}) {
    if (_outlineItems == null) return null;

    Iterable<OutlineItem> searchSequence =
        atBottom ? _outlineItems.reversed : _outlineItems;
    for (OutlineItem item in searchSequence) {
      // Unlike [_itemAtCodeOffset], this function is called when the user
      // scrolls the cursor with the mouse or moves it with the arrow keys.
      // In that case, there is always a prior position with a prior item
      // already selected in the outline. So not finding anything and doing
      // nothing is fine.
      if (item.offsetRange.intersects(codeOffsetRange)) return item;
    }
    return null;
  }
}

abstract class OutlineItem {
  services.OutlineEntry _data;
  html.LIElement _element;
  html.AnchorElement _anchor;
  html.SpanElement _typeSpan;
  OffsetRange _offsetRange;

  OutlineItem(this._data, String cssClassName) {
    _offsetRange = new OffsetRange(_data.bodyStartOffset, _data.bodyEndOffset);

    _element = new html.LIElement();

    _anchor = new html.AnchorElement(href: "#");
    _anchor.text = displayName;
    _anchor.onClick.listen((_) =>
        _element.dispatchEvent(new html.CustomEvent('selected', detail: this)));
    _element.append(_anchor);

    if (returnType != null && returnType.isNotEmpty) {
      _typeSpan = new html.SpanElement();
      _typeSpan.text = returnType;
      _typeSpan.classes.add("returnType");
      _element.append(_typeSpan);
    }

    _element.classes.add("outlineItem ${cssClassName}");
  }

  String get displayName => _data.name;
  String get returnType => null;

  Stream get onClick => _anchor.onClick;

  int get nameStartOffset => _data.nameStartOffset;
  int get nameEndOffset => _data.nameEndOffset;

  OffsetRange get offsetRange => _offsetRange;

  html.LIElement get element => _element;
  html.AnchorElement get anchor => _anchor;

  void setSelected(bool selected) {
    _element.classes.toggle("selected", selected);
  }

  void scrollIntoView() => _element.scrollIntoView();

  @override
  String toString() =>
      "$runtimeType $displayName ($_offsetRange)";
}

abstract class OutlineTopLevelItem extends OutlineItem {
  OutlineTopLevelItem(services.OutlineTopLevelEntry data, String cssClassName)
      : super(data, "topLevel $cssClassName");
}

class OutlineTopLevelVariable extends OutlineTopLevelItem {
  OutlineTopLevelVariable(services.OutlineTopLevelVariable data)
      : super(data, "variable");

  services.OutlineTopLevelVariable get _variableData => _data;
  String get returnType => _variableData.returnType;
}

class OutlineTopLevelFunction extends OutlineTopLevelItem {
  OutlineTopLevelFunction(services.OutlineTopLevelFunction data)
      : super(data, "function");

  services.OutlineTopLevelFunction get _functionData => _data;
  String get returnType => _functionData.returnType;
}

class OutlineTopLevelAccessor extends OutlineTopLevelItem {
  OutlineTopLevelAccessor(services.OutlineTopLevelAccessor data)
      : super(data, "accessor ${data.setter ? 'setter' : 'getter'}");

  services.OutlineTopLevelAccessor get _accessorData => _data;

  String get displayName => _data.name;
  String get returnType => _accessorData.returnType;
}

class OutlineTypeDef extends OutlineTopLevelItem {
  OutlineTypeDef(services.OutlineTypeDef data) : super(data, "typedef");
}

class OutlineClass extends OutlineTopLevelItem {
  html.UListElement _childrenRootElement = new html.UListElement();
  List<OutlineClassMember> members = [];

  OutlineClass(services.OutlineClass data)
      : super(data, "class") {
    _element.append(_childrenRootElement);
    _populate(data);
    _postProcess();
  }

  OutlineClassMember _addItem(OutlineClassMember item) {
    _childrenRootElement.append(item.element);
    members.add(item);
    return item;
  }

  void _populate(services.OutlineClass classData) {
    for (services.OutlineEntry data in classData.members) {
      _createMember(data);
    }
  }

  /**
   * Clip the class's and constructor's offsetRanges to the actual ones.
   * As provided by Ace (?), they both span the entire class's definition
   * (for constructors, it's likely a bug), which is not what we want when
   * highlighting or scrolling them into view.
   */
  void _postProcess() {
    // Class's offsetRange.
    if (members.length > 0) {
      _offsetRange.bottom = members[0]._offsetRange.top - 1;
    }
    // Constructors' offsetRanges.
    for (int i = 0; i < members.length; ++i) {
      OutlineItem member = members[i];
      if (member._data.name == _data.name ||
          member._data.name.startsWith("${_data.name}.")) {
        if (i > 0) {
          member._offsetRange.top = members[i - 1]._offsetRange.bottom + 1;
        }
        if (i < members.length - 1) {
          member._offsetRange.bottom = members[i + 1]._offsetRange.top - 1;
        }
      }
    }
  }

  OutlineItem _createMember(services.OutlineEntry data) {
    if (data is services.OutlineMethod) {
      return addMethod(data);
    } else if (data is services.OutlineProperty) {
      return addProperty(data);
    } else if (data is services.OutlineClassAccessor) {
      return addAccessor(data);
    } else {
      throw new UnimplementedError("Unknown type");
    }
  }

  OutlineMethod addMethod(services.OutlineMethod data) =>
      _addItem(new OutlineMethod(data));

  OutlineProperty addProperty(services.OutlineProperty data) =>
      _addItem(new OutlineProperty(data));

  OutlineClassAccessor addAccessor(services.OutlineClassAccessor data) =>
      _addItem(new OutlineClassAccessor(data));
}

abstract class OutlineClassMember extends OutlineItem {
  OutlineClassMember(services.OutlineMember data, String cssClassName)
      : super(data, cssClassName);
}

class OutlineMethod extends OutlineClassMember {
  OutlineMethod(services.OutlineMethod data)
      : super(data, "method");

  services.OutlineMethod get _methodData => _data;
  String get returnType => _methodData.returnType;
}

class OutlineProperty extends OutlineClassMember {
  OutlineProperty(services.OutlineProperty data)
      : super(data, "property");

  services.OutlineProperty get _propertyData => _data;
  String get returnType => _propertyData.returnType;
}

class OutlineClassAccessor extends OutlineClassMember {
  OutlineClassAccessor(services.OutlineClassAccessor data)
      : super(data, "accessor ${data.setter ? 'setter' : 'getter'}");

  services.OutlineClassAccessor get _accessorData => _data;

  String get displayName => _data.name;
  String get returnType => _accessorData.returnType;
}
