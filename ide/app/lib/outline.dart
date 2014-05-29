// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.outline;

import 'dart:async';
import 'dart:html' as html;

import '../lib/services.dart' as services;
import 'preferences.dart';

/**
 * Defines a class to build an outline UI for a given block of code.
 */
class Outline {
  Map<int, OutlineItem> _outlineItemsByOffset;
  OutlineItem _selectedItem;

  html.Element _container;
  html.DivElement _outlineDiv;
  html.UListElement _rootList;

  html.ButtonElement _outlineButton;
  html.SpanElement _scrollTarget;
  int _initialScrollPosition = 0;

  final PreferenceStore _prefs;
  bool _visible = true;

  services.AnalyzerService _analyzer;

  StreamController<OutlineItem> _childSelectedController = new StreamController();

  Outline(this._analyzer, this._container, this._prefs) {
    // Use template to create the UI of outline.
    html.DocumentFragment template =
        (html.querySelector('#outline-template') as
        html.TemplateElement).content;
    html.DocumentFragment templateClone = template.clone(true);
    _outlineDiv = templateClone.querySelector('#outline');
    _outlineDiv.onMouseWheel.listen((html.MouseEvent event) =>
        event.stopPropagation());
    _rootList = templateClone.querySelector('#outline ul');
    template =
        (html.querySelector('#outline-button-template') as
        html.TemplateElement).content;
    templateClone = template.clone(true);
    _outlineButton = templateClone.querySelector('#toggleOutlineButton');
    _outlineButton.onClick.listen((e) => toggle());

    _container.children.add(_outlineButton);
    _prefs.getValue('OutlineCollapsed').then((String data) {
      if (data == 'true') {
        _outlineDiv.classes.add('collapsed');
      }
      _container.children.add(_outlineDiv);
    });
  }

  Stream<OutlineItem> get onChildSelected => _childSelectedController.stream;

  Stream get onScroll => _outlineDiv.onScroll;

  int get scrollPosition => _rootList.parent.scrollTop.toInt();
  void set scrollPosition(int position) {
    // If the outline has not been built yet, just save the position
    _initialScrollPosition = position;
    if (_scrollTarget != null) {
      _scrollIntoView(_outlineDiv.clientHeight, position);
    }
  }

  void _scrollIntoView(num top, num bottom) {
    // Hack for scrollTop not working
    _scrollTarget.hidden = false;
    _scrollTarget.style
        ..position = "absolute"
        ..height = "${bottom - top}px"
        ..top = "${top}px";
    _scrollTarget.scrollIntoView();
    _scrollTarget.hidden = true;
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
    _outlineItemsByOffset = {};
    _rootList.children.clear();
    _scrollTarget = new html.SpanElement();
    _rootList.append(_scrollTarget);

    for (services.OutlineTopLevelEntry data in outline.entries) {
      OutlineItem item = _create(data);
      _outlineItemsByOffset[item.bodyStartOffset] = item;
    }

    if (_initialScrollPosition != null) scrollPosition = _initialScrollPosition;
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
    item.onClick.listen((event) => _childSelectedController.add(item));
    return item;
  }

  OutlineTopLevelVariable _addVariable(services.OutlineTopLevelVariable data) =>
      _addItem(new OutlineTopLevelVariable(data));

  OutlineTopLevelFunction _addFunction(services.OutlineTopLevelFunction data) =>
      _addItem(new OutlineTopLevelFunction(data));

  OutlineClass _addClass(services.OutlineClass data) {
    OutlineClass classItem = new OutlineClass(data, _outlineItemsByOffset);
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

  void scrollToOffsets(int firstCursorOffset, int lastCursorOffset) {
    List<html.Node> outlineElements =
        _outlineDiv.getElementsByClassName("outlineItem");

    if (outlineElements.length > 0) {
      int firstItemIndex = _itemIndexAtCodeOffset(firstCursorOffset);
      int lastItemIndex = _itemIndexAtCodeOffset(lastCursorOffset);

      html.Element firstElement = outlineElements[firstItemIndex];

      num bottomOffset;
      if (outlineElements.length > lastItemIndex + 1) {
        html.Element element = outlineElements[lastItemIndex + 1];
        bottomOffset = element.offsetTop;
      } else {
        html.Element lastElement = outlineElements[lastItemIndex];
        bottomOffset = lastElement.offsetTop + lastElement.offsetHeight;
      }

      _scrollIntoView(firstElement.offsetTop, bottomOffset);
    }
  }

  int _itemIndexAtCodeOffset(int codeOffset, {bool returnCodeOffset: false}) {
    if (_outlineItemsByOffset != null) {
      int count = 0;
      List<int> outlineOffsets = _outlineItemsByOffset.keys.toList()..sort();
      int containerOffset = returnCodeOffset ? outlineOffsets[0] : 0;

      // Finds the last outline item that *doesn't* satisfies this:
      for (int outlineOffset in outlineOffsets) {
        if (outlineOffset > codeOffset) break;
        containerOffset = returnCodeOffset ? outlineOffset : count;
        count++;
      }
      return containerOffset;
    } else {
      return null;
    }
  }

  OutlineItem _itemAtCodeOffset(int codeOffset) {
    int itemIndex = _itemIndexAtCodeOffset(codeOffset, returnCodeOffset: true);
    if (itemIndex != null) {
      return _outlineItemsByOffset[itemIndex];
    }
    return null;
  }
}

abstract class OutlineItem {
  services.OutlineEntry _data;
  html.LIElement _element;
  html.AnchorElement _anchor;
  html.SpanElement _nameSpan;
  String get displayName => _data.name;

  OutlineItem(this._data, String cssClassName) {
    _element = new html.LIElement();

    _anchor = new html.AnchorElement(href: "#");
    _element.append(_anchor);

    _nameSpan = new html.SpanElement()
        ..text = displayName;
    _anchor.append(_nameSpan);

    _element.classes.add("outlineItem $cssClassName");
  }

  Stream get onClick => _anchor.onClick;
  int get nameStartOffset => _data.nameStartOffset;
  int get nameEndOffset => _data.nameEndOffset;
  int get bodyStartOffset => _data.bodyStartOffset;
  int get bodyEndOffset => _data.bodyEndOffset;
  html.LIElement get element => _element;

  void setSelected(bool selected) {
    _element.classes.toggle("selected", selected);
  }

  void scrollIntoView() => _element.scrollIntoView();
}

abstract class OutlineTopLevelItem extends OutlineItem {
  OutlineTopLevelItem(services.OutlineTopLevelEntry data, String cssClassName)
      : super(data, "topLevel $cssClassName");
}

class OutlineTopLevelVariable extends OutlineTopLevelItem {
  services.OutlineTopLevelVariable get _variableData => _data;
  html.SpanElement _typeSpan;

  OutlineTopLevelVariable(services.OutlineTopLevelVariable data)
      : super(data, "variable") {
    if (returnType != "") {
      _typeSpan = new html.SpanElement();
      _typeSpan.text = returnType;
      _typeSpan.classes.add("returnType");
      _anchor.append(_typeSpan);
    }
  }

  String get returnType => _variableData.returnType;
}

class OutlineTopLevelFunction extends OutlineTopLevelItem {
  OutlineTopLevelFunction(services.OutlineTopLevelFunction data)
      : super(data, "function");
}

class OutlineClass extends OutlineTopLevelItem {
  html.UListElement _childrenRootElement = new html.UListElement();

  List<OutlineClassMember> members = [];
  StreamController childSelectedController = new StreamController();
  Stream get onChildSelected => childSelectedController.stream;
  Map<int, OutlineItem> _outlineItemsByOffset;

  OutlineClass(services.OutlineClass data, this._outlineItemsByOffset)
      : super(data, "class") {
    _element.append(_childrenRootElement);
    _populate(data);
  }

  OutlineClassMember _addItem(OutlineClassMember item) {
    _childrenRootElement.append(item.element);
    item.onClick.listen((event) => childSelectedController.add(item));
    members.add(item);
    return item;
  }

  void _populate(services.OutlineClass classData) {
    for (services.OutlineEntry data in classData.members) {
      OutlineItem item = _create(data);
      _outlineItemsByOffset[item.bodyStartOffset] = item;
    }
  }

  OutlineItem _create(services.OutlineEntry data) {
    if (data is services.OutlineMethod) {
      return addMethod(data);
    } else if (data is services.OutlineProperty) {
      return addProperty(data);
    } else if (data is services.OutlineAccessor) {
      return addAccessor(data);
    } else {
      throw new UnimplementedError("Unknown type");
    }
  }

  OutlineMethod addMethod(services.OutlineMethod data) =>
      _addItem(new OutlineMethod(data));

  OutlineProperty addProperty(services.OutlineProperty data) =>
      _addItem(new OutlineProperty(data));

  OutlineAccessor addAccessor(services.OutlineAccessor data) =>
      _addItem(new OutlineAccessor(data));
}

abstract class OutlineClassMember extends OutlineItem {
  OutlineClassMember(services.OutlineMember data, String cssClassName)
      : super(data, cssClassName);
}

class OutlineMethod extends OutlineClassMember {
  OutlineMethod(services.OutlineMethod data)
      : super(data, "method");
}

class OutlineProperty extends OutlineClassMember {
  html.SpanElement _typeSpan;

  OutlineProperty(services.OutlineProperty data)
      : super(data, "property") {
    if (returnType != "") {
      _typeSpan = new html.SpanElement();
      _typeSpan.text = returnType;
      _typeSpan.classes.add("returnType");
      _anchor.append(_typeSpan);
    }
  }

  services.OutlineProperty get _propertyData => _data;
  String get returnType => _propertyData.returnType;
}

class OutlineAccessor extends OutlineClassMember {
  String get displayName => _data.name;
  OutlineAccessor(services.OutlineAccessor data)
      : super(data, "accessor ${data.setter ? 'setter' : 'getter'}");
}
