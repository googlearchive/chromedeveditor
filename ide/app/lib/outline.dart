// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:html' as html;

import '../lib/services.dart' as services;

/**
 * Defines a class to build an outline UI for a given block of code.
 */
class Outline {
  html.DivElement _outlineDiv;
  html.UListElement _rootList;
  html.DivElement _outlineContainer;

  services.AnalyzerService analyzer;

  List<OutlineTopLevelItem> children = [];
  StreamController childSelectedController = new StreamController();
  Stream get onChildSelected => childSelectedController.stream;

  Outline(services.Services services, this._outlineDiv) {
    analyzer = services.getService("analyzer");

    _outlineDiv.style
        ..position = 'absolute'
        ..minWidth = '40px'
        ..right = '10px'
        ..top ='10px'
        ..bottom = '10px'
        ..background = 'rgb(100, 100, 100)'
        ..borderRadius = '2px'
        ..zIndex = '100'
        ..opacity = '0.6'
        ..overflow = 'scroll';

    _outlineContainer = new html.DivElement();
    _outlineContainer.style
        ..height = '100%'
        ..width = '200px'
        ..overflow = 'scroll';
    _outlineDiv.append(_outlineContainer);

    html.ButtonElement toggleButton = new html.ButtonElement();
    toggleButton
        ..onClick.listen((e) => e.target.text = _toggle() ? ">" : "<")
        ..text = ">";

    toggleButton.style
        ..position = 'absolute'
        ..height ='20px'
        ..top ='50%'
        ..bottom ='50%';

    _outlineDiv.append(toggleButton);
  }

  /**
   * Builds or rebuilds the outline UI based on the given String of code.
   */
  Future build(String code) {
    return analyzer.getOutlineFor(code).then((services.Outline model) {
      _populate(model);
    });
  }

  void _populate(services.Outline outline) {
    // TODO(ericarnold): Is there anything else that needs to be done to
    //    emsure there are no memory leaks?
    children = [];
    if (_rootList != null) {
      _rootList.remove();
    }

    _rootList = new html.UListElement();
    _outlineContainer.append(_rootList);

    for (services.OutlineTopLevelEntry data in outline.entries) {
      _create(data);
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
  bool _toggle() {
    if (_outlineContainer.style.display == 'none') {
      _outlineContainer.style.display = 'block';
      return true;
    } else {
      _outlineContainer.style.display = 'none';
      return false;
    }
  }

  OutlineTopLevelItem _addItem(OutlineTopLevelItem item) {
    _rootList.append(item._element);
    item.onClick.listen((event) => childSelectedController.add(item));
    children.add(item);
    return item;
  }

  OutlineTopLevelVariable _addVariable(services.OutlineTopLevelVariable data) =>
      _addItem(new OutlineTopLevelVariable(data));

  OutlineTopLevelFunction _addFunction(services.OutlineTopLevelFunction data) =>
      _addItem(new OutlineTopLevelFunction(data));

  OutlineClass _addClass(services.OutlineClass data) {
    OutlineClass classItem = new OutlineClass(data);
    classItem.onChildSelected.listen((event) =>
        childSelectedController.add(event));
    _addItem(classItem);
    _rootList.append(classItem._rootElement);
    return classItem;
  }
}

abstract class OutlineItem {
  html.LIElement _element;
  services.OutlineEntry _data;
  html.AnchorElement _anchor;
  Stream get onClick => _anchor.onClick;
  int get startOffset => _data.startOffset;
  int get endOffset => _data.endOffset;

  OutlineItem(this._data) {
    _element = new html.LIElement();
    _anchor = new html.AnchorElement(href: "#");
    _element.append(_anchor);
    _anchor.text = _data.name;
  }
}

abstract class OutlineTopLevelItem extends OutlineItem {
  OutlineTopLevelItem(services.OutlineTopLevelEntry data) : super(data);
}

class OutlineTopLevelVariable extends OutlineTopLevelItem {
  OutlineTopLevelVariable(services.OutlineTopLevelVariable data) : super(data);
}

class OutlineTopLevelFunction extends OutlineTopLevelItem {
  OutlineTopLevelFunction(services.OutlineTopLevelFunction data) : super(data);
}

class OutlineClass extends OutlineTopLevelItem {
  var _rootElement = new html.UListElement();
  List<OutlineClassMember> members = [];
  StreamController childSelectedController = new StreamController();
  Stream get onChildSelected => childSelectedController.stream;

  OutlineClass(services.OutlineClass data) : super(data) {
    _populate(data);
  }

  OutlineClassMember _addItem(OutlineClassMember item) {
    _rootElement.append(item._element);
    item.onClick.listen((event) => childSelectedController.add(item));
    members.add(item);
    return item;
  }

  void _populate(services.OutlineClass classData) {
    for (services.OutlineEntry data in classData.members) {
      _create(data);
    }
  }

  OutlineItem _create(services.OutlineEntry data) {
    if (data is services.OutlineMethod) {
      return addMethod(data);
    } else if (data is services.OutlineProperty) {
      return addProperty(data);
    } else {
      throw new UnimplementedError("Unknown type");
    }
  }

  OutlineMethod addMethod(services.OutlineMethod data) =>
      _addItem(new OutlineMethod(data));
  OutlineProperty addProperty(services.OutlineProperty data) =>
      _addItem(new OutlineProperty(data));
}

class OutlineMethod extends OutlineClassMember {
  OutlineMethod(services.OutlineMethod data) : super(data);
}

abstract class OutlineClassMember extends OutlineItem {
  OutlineClassMember(services.OutlineMember data) : super(data);
}

class OutlineProperty extends OutlineClassMember {
  OutlineProperty(services.OutlineProperty data) : super(data);
}

