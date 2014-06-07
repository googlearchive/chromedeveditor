// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.outline;

import 'dart:async';
import 'dart:html' as html;

import '../lib/services.dart' as services;
import 'preferences.dart';

final bool _INCLUDE_TYPES = true;

class OffsetRange {
  int top;
  int bottom;
  int get center => (top + bottom) ~/ 2;

  OffsetRange([this.top = 0, this.bottom = 0]);

  bool centeredSame(OffsetRange another) => center == another.center;
  bool centeredHigher(OffsetRange another) => top < another.top;
  bool centeredLower(OffsetRange another) => bottom > another.bottom;

  bool includes(int offset) => offset >= top && offset <= bottom;
  bool overlaps(OffsetRange another) =>
      !(bottom < another.top || top > another.bottom);

  String toString() => "($top, $bottom)";
}

/**
 * Defines a class to build an outline UI for a given block of code.
 */
class Outline {
  List<OutlineItem> _outlineItems;
  OutlineItem _selectedItem;
  OffsetRange _lastScrolledOffsetRange;

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

  bool get visible => !_outlineDiv.classes.contains('collapsed');
  set visible(bool value) {
    _visible = value;
    _outlineDiv.classes.toggle('hidden', !_visible);
    _outlineButton.classes.toggle('hidden', !_visible);
  }

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

    for (var item in _outlineItems) {
      print("${item._offsetRange} -> ${item._data.runtimeType} ${item._data.name}");
    }

    if (_lastScrolledOffsetRange != null) scrollPosition = _lastScrolledOffsetRange;
  }

  OutlineTopLevelItem _create(services.OutlineTopLevelEntry data) {
    if (data is services.OutlineClass) {
      return _addClass(data);
    } else if (data is services.OutlineTopLevelVariable) {
      return _addVariable(data);
    } else if (data is services.OutlineTopLevelFunction) {
      return _addFunction(data);
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

  OutlineTopLevelItem _addItem(OutlineTopLevelItem item) {
    _rootList.append(item.element);
    _outlineItems.add(item);
    item.onClick.listen((event) => _childSelectedController.add(item));
    return item;
  }

  OutlineTopLevelVariable _addVariable(services.OutlineTopLevelVariable data) =>
      _addItem(new OutlineTopLevelVariable(data, _outlineItems));

  OutlineTopLevelFunction _addFunction(services.OutlineTopLevelFunction data) =>
      _addItem(new OutlineTopLevelFunction(data, _outlineItems));

  OutlineClass _addClass(services.OutlineClass data) {
    OutlineClass classItem = new OutlineClass(data, _outlineItems);
    classItem.onChildSelected.listen((event) =>
        _childSelectedController.add(event));
    _addItem(classItem);
    return classItem;
  }

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

  void scrollOffsetRangeIntoView(OffsetRange offsetRange) {
    OutlineItem item;
    html.ScrollAlignment alignment;

    if (offsetRange.centeredLower(_lastScrolledOffsetRange)) {
      // Scrolling down: give priority to the last item.
      item = _itemAtCodeOffset(offsetRange.bottom);
      alignment = html.ScrollAlignment.BOTTOM;
    } else if (offsetRange.centeredHigher(_lastScrolledOffsetRange)) {
      // Scrolling up: give priority to the first item.
      item = _itemAtCodeOffset(offsetRange.top);
      alignment = html.ScrollAlignment.TOP;
    } else {
      // Haven't scrolled enough. Do nothing.
    }

    if (item != null) {
      _scrollItemIntoView(item, alignment);
      _lastScrolledOffsetRange = offsetRange;
    }
  }

  void _scrollItemIntoView(OutlineItem item, html.ScrollAlignment alignment) {
    html.Rectangle rootListRect = _rootListDiv.getBoundingClientRect();
    html.Rectangle elementRect = item.element.getBoundingClientRect();
    // Perhaps the item is already in view.
    if (!rootListRect.containsRectangle(elementRect)) {
      item.element.scrollIntoView(alignment);
    }
  }

  OutlineItem _itemAtCodeOffset(int codeOffset) {
    if (_outlineItems == null) return null;

    for (OutlineItem item in _outlineItems) {
      if (item.overlapsOffset(codeOffset)) {
        print("  found ${item._offsetRange} -> ${item._data.runtimeType} ${item._data.name}");
        return item;
      }
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

  OutlineItem(this._data, String cssClassName, List<OutlineItem> outlineItems) {
    _offsetRange = new OffsetRange(_data.bodyStartOffset, _data.bodyEndOffset);

    _element = new html.LIElement();

    _anchor = new html.AnchorElement(href: "#");
    _anchor.text = displayName;
    _element.append(_anchor);

    if (_INCLUDE_TYPES && returnType != null && returnType.isNotEmpty) {
     _typeSpan = new html.SpanElement();
     _typeSpan.text = returnType;
     _typeSpan.classes.add("returnType");
     _element.append(_typeSpan);
    }

    _element.classes.add("outlineItem ${cssClassName}");

    outlineItems.add(this);
  }

  String get displayName => _data.name;
  String get returnType => null;

  Stream get onClick => _anchor.onClick;

  int get nameStartOffset => _data.nameStartOffset;
  int get nameEndOffset => _data.nameEndOffset;

  bool overlapsOffset(int offset) => _offsetRange.includes(offset);
  bool overlapsOffsetRange(OffsetRange range) => _offsetRange.overlaps(range);

  html.LIElement get element => _element;

  void setSelected(bool selected) {
    _element.classes.toggle("selected", selected);
  }

  void scrollIntoView() => _element.scrollIntoView();
}

abstract class OutlineTopLevelItem extends OutlineItem {
  OutlineTopLevelItem(services.OutlineTopLevelEntry data,
                      String cssClassName,
                      List<OutlineItem> outlineItems)
      : super(data, "topLevel $cssClassName", outlineItems);
}

class OutlineTopLevelVariable extends OutlineTopLevelItem {
  OutlineTopLevelVariable(services.OutlineTopLevelVariable data,
                          List<OutlineItem> outlineItems)
      : super(data, "variable", outlineItems);

  services.OutlineTopLevelVariable get _variableData => _data;
  String get returnType => _variableData.returnType;
}

class OutlineTopLevelFunction extends OutlineTopLevelItem {
  OutlineTopLevelFunction(services.OutlineTopLevelFunction data,
                          List<OutlineItem> outlineItems)
      : super(data, "function", outlineItems);

  services.OutlineTopLevelFunction get _functionData => _data;
  String get returnType => _functionData.returnType;
}

class OutlineClass extends OutlineTopLevelItem {
  html.UListElement _childrenRootElement = new html.UListElement();

  List<OutlineClassMember> members = [];
  StreamController childSelectedController = new StreamController();
  Stream get onChildSelected => childSelectedController.stream;

  OutlineClass(services.OutlineClass data, List<OutlineItem> outlineItems)
      : super(data, "class", outlineItems) {
    _element.append(_childrenRootElement);
    _populate(data, outlineItems);
  }

  OutlineClassMember _addItem(OutlineClassMember item) {
    _childrenRootElement.append(item.element);
    item.onClick.listen((event) => childSelectedController.add(item));
    members.add(item);
    return item;
  }

  void _populate(services.OutlineClass classData,
                 List<OutlineItem> outlineItems) {
    for (services.OutlineEntry data in classData.members) {
      _createMember(data, outlineItems);
    }
  }

  OutlineItem _createMember(services.OutlineEntry data,
                            List<OutlineItem> outlineItems) {
    if (data is services.OutlineMethod) {
      return addMethod(data, outlineItems);
    } else if (data is services.OutlineProperty) {
      return addProperty(data, outlineItems);
    } else if (data is services.OutlineAccessor) {
      return addAccessor(data, outlineItems);
    } else {
      throw new UnimplementedError("Unknown type");
    }
  }

  OutlineMethod addMethod(services.OutlineMethod data,
                          List<OutlineItem> outlineItems) =>
      _addItem(new OutlineMethod(data, outlineItems));

  OutlineProperty addProperty(services.OutlineProperty data,
                              List<OutlineItem> outlineItems) =>
      _addItem(new OutlineProperty(data, outlineItems));

  OutlineAccessor addAccessor(services.OutlineAccessor data,
                              List<OutlineItem> outlineItems) =>
      _addItem(new OutlineAccessor(data, outlineItems));
}

abstract class OutlineClassMember extends OutlineItem {
  OutlineClassMember(services.OutlineMember data,
                     String cssClassName,
                     List<OutlineItem> outlineItems)
      : super(data, cssClassName, outlineItems);
}

class OutlineMethod extends OutlineClassMember {
  OutlineMethod(services.OutlineMethod data, List<OutlineItem> outlineItems)
      : super(data, "method", outlineItems);

  services.OutlineMethod get _methodData => _data;
  String get returnType => _methodData.returnType;
}

class OutlineProperty extends OutlineClassMember {
  OutlineProperty(services.OutlineProperty data, List<OutlineItem> outlineItems)
      : super(data, "property", outlineItems);

  services.OutlineProperty get _propertyData => _data;
  String get returnType => _propertyData.returnType;
}

class OutlineAccessor extends OutlineClassMember {
  OutlineAccessor(services.OutlineAccessor data, List<OutlineItem> outlineItems)
      : super(data,
              "accessor ${data.setter ? 'setter' : 'getter'}",
              outlineItems);

  services.OutlineAccessor get _accessorData => _data;

  String get displayName => _data.name;
  String get returnType => _accessorData.returnType;
}
