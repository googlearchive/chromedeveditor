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

  StreamSubscription _currentOutlineOperation;
  Completer _buildCompleter;

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
    _outlineButton.onClick.listen((e) => _toggle());

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

  int get scrollPosition => _rootList.parent.scrollTop;
  void set scrollPosition(int position) {
    // If the outline has not been built yet, just save the position
    _initialScrollPosition = position;
    if (_scrollTarget != null) {
      // Hack for scrollTop not working
      _scrollTarget.hidden = false;
      _scrollTarget.style
          ..position = "absolute"
          ..height = "${_outlineDiv.clientHeight}px"
          ..top = "${position}px";
      _scrollTarget.scrollIntoView();
      _scrollTarget.hidden = true;
    }
  }

  bool get visible => !_outlineDiv.classes.contains('collapsed');
  set visible(bool value) {
    _visible = value;
    _outlineDiv.classes.toggle('hidden', !_visible);
    _outlineButton.classes.toggle('hidden', !_visible);
  }

  /**
   * Builds or rebuilds the outline UI based on the given String of code.
   * Returns a subscription which can be canceled to cancel the outline.
   */
  Future build(String name, String code) {
    if (_currentOutlineOperation != null) {
      _currentOutlineOperation.cancel();
    }

    if (_buildCompleter != null && !_buildCompleter.isCompleted) {
      _buildCompleter.complete();
    }

    _buildCompleter = new Completer();

    _currentOutlineOperation =
        _analyzer.getOutlineFor(code, name).asStream().listen(
            (services.Outline model) => _populate(model));
    _currentOutlineOperation.onDone(() => _buildCompleter.complete);

    return _buildCompleter.future;
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
   * Toggles visibility of the outline.  Returns true if showing.
   */
  void _toggle() {
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
    Map<int, OutlineItem> outlineItems = _outlineItemsByOffset;
    if (outlineItems != null) {
      int containerOffset = -1;

      var outlineOffets = outlineItems.keys.toList()..sort();

      // Finds the last outline item that *doesn't* satisfies this:
      for (int outlineOffset in outlineOffets) {
        if (outlineOffset > cursorOffset) break;
        containerOffset = outlineOffset;
      }

      if (containerOffset != -1) {
        setSelected(outlineItems[containerOffset]);
      }
    }
  }
}

abstract class OutlineItem {
  html.LIElement _element;
  services.OutlineEntry _data;
  html.AnchorElement _anchor;
  html.SpanElement _nameSpan;
  String get displayName => _data.name;

  OutlineItem(this._data, String cssClassName) {
    _element = new html.LIElement();
    _nameSpan = new html.SpanElement();
    _anchor = new html.AnchorElement(href: "#");
    _nameSpan.text = displayName;

    _element.append(_anchor);
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
  OutlineTopLevelVariable(services.OutlineTopLevelVariable data)
      : super(data, "variable");
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
  services.OutlineProperty get _propertyData => _data;

  String get type => _propertyData.returnType;
  html.SpanElement _typeSpan;

  OutlineProperty(services.OutlineProperty data)
      : super(data, "property") {
    _typeSpan = new html.SpanElement();
    _typeSpan.text = type;
    _typeSpan.classes.add("returnType");
    _anchor.append(_typeSpan);
  }
}

class OutlineAccessor extends OutlineClassMember {
  String get displayName => _data.name;
  OutlineAccessor(services.OutlineAccessor data)
      : super(data, "accessor ${data.setter ? 'setter' : 'getter'}");
}
