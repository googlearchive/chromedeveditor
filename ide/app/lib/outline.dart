// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.outline;

import 'dart:async';
import 'dart:html' as html;

import '../lib/services.dart' as services;

/**
 * Defines a class to build an outline UI for a given block of code.
 */
class Outline {
  Map<int, OutlineItem> outlineItemsByOffset;
  OutlineItem selectedItem;

  StreamSubscription _currentOutlineOperation;
  Completer _buildCompleter;

  html.Element _container;
  html.DivElement _outlineDiv;
  html.UListElement _rootList;
  StreamController _childSelectedController = new StreamController();

  services.AnalyzerService _analyzer;

  Outline(this._analyzer, this._container) {
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
    html.ButtonElement button =
        templateClone.querySelector('#toggleOutlineButton');
    button.onClick.listen((e) => _toggle());

    _container.children.add(_outlineDiv);
    _container.children.add(button);
  }

  Stream get onChildSelected => _childSelectedController.stream;

  bool get visible => !_outlineDiv.classes.contains('collapsed');
  set visible(bool value) {
    if (value != visible) {
      _outlineDiv.classes.toggle('collapsed');
    }
  }

  /**
   * Builds or rebuilds the outline UI based on the given String of code.
   *
   * @return A subscription which can be canceled to cancel the outline.
   */
  Future build(String code) {
    if (_currentOutlineOperation != null) {
      _currentOutlineOperation.cancel();
    }

    if (_buildCompleter != null && !_buildCompleter.isCompleted) {
      _buildCompleter.complete();
    }

    _buildCompleter = new Completer();

    _currentOutlineOperation = _analyzer.getOutlineFor(code).asStream()
        .listen((services.Outline model) => _populate(model));

    _currentOutlineOperation.onDone(() => _buildCompleter.complete);

    return _buildCompleter.future;
  }

  void _populate(services.Outline outline) {
    outlineItemsByOffset = {};
    _rootList.children.clear();
    for (services.OutlineTopLevelEntry data in outline.entries) {
      OutlineItem item = _create(data);
      outlineItemsByOffset[item.bodyStartOffset] = item;
    }
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
    OutlineClass classItem = new OutlineClass(data, outlineItemsByOffset);
    classItem.onChildSelected.listen((event) =>
        _childSelectedController.add(event));
    _addItem(classItem);
    return classItem;
  }

  void setCurrentItem(OutlineItem itemAtCursor) {
    if (selectedItem != null) {
      selectedItem.setSelected(false);
    }
    selectedItem = itemAtCursor;
    selectedItem.setSelected(true);
  }
}

abstract class OutlineItem {
  html.LIElement _element;
  services.OutlineEntry _data;
  html.AnchorElement _anchor;
  String get displayName => _data.name;

  OutlineItem(this._data, String cssClassName) {
    _element = new html.LIElement();
    _anchor = new html.AnchorElement(href: "#");
    _anchor.text = displayName;

    _element.append(_anchor);
    _element.classes.add("outlineItem $cssClassName");
  }

  Stream get onClick => _anchor.onClick;
  int get nameStartOffset => _data.nameStartOffset;
  int get nameEndOffset => _data.nameEndOffset;
  int get bodyStartOffset => _data.bodyStartOffset;
  int get bodyEndOffset => _data.bodyEndOffset;
  html.LIElement get element => _element;

  void setSelected(bool selected) {
    if (selected) {
      _element.classes.add("selected");
    } else {
      _element.classes.remove("selected");
    }
  }
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
  OutlineProperty(services.OutlineProperty data)
      : super(data, "property");
}

class OutlineAccessor extends OutlineClassMember {
  String get displayName => _data.name;
  OutlineAccessor(services.OutlineAccessor data)
      : super(data, "accessor ${data.setter ? 'setter' : 'getter'}");
}
