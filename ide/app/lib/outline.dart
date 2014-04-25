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
  StreamSubscription _currentOutlineOperation;
  Completer _buildCompleter;

  html.Element _container;
  html.DivElement _outlineDiv;
  html.UListElement _rootList;
  html.ButtonElement _outlineButton;

  final PreferenceStore _prefs;
  bool _visible = true;

  services.AnalyzerService analyzer;

  StreamController childSelectedController = new StreamController();
  Stream get onChildSelected => childSelectedController.stream;

  Outline(services.Services services, this._container, this._prefs) {
    analyzer = services.getService("analyzer");

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

  bool get visible => _visible;
  set visible(bool value) {
    _visible = value;
    _outlineDiv.classes.toggle('hidden', !_visible);
    _outlineButton.classes.toggle('hidden', !_visible);
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

    _currentOutlineOperation = analyzer.getOutlineFor(code).asStream()
        .listen((services.Outline model) => _populate(model));

    _currentOutlineOperation.onDone(() => _buildCompleter.complete);

    return _buildCompleter.future;
  }

  void _populate(services.Outline outline) {
    _rootList.children.clear();
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
  void _toggle() {
    _outlineDiv.classes.toggle('collapsed');
    String value = _outlineDiv.classes.contains('collapsed') ? 'true' : 'false';
    _prefs.setValue('OutlineCollapsed', value);
  }

  OutlineTopLevelItem _addItem(OutlineTopLevelItem item) {
    _rootList.append(item.element);
    item.onClick.listen((event) => childSelectedController.add(item));
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
    return classItem;
  }
}

abstract class OutlineItem {
  html.LIElement _element;
  services.OutlineEntry _data;
  html.AnchorElement _anchor;
  get displayName => _data.name;

  OutlineItem(this._data, String cssClassName) {
    _element = new html.LIElement();
    _anchor = new html.AnchorElement(href: "#");
    _anchor.text = displayName;

    _element.append(_anchor);
    _element.classes.add("outlineItem $cssClassName");
  }

  Stream get onClick => _anchor.onClick;
  int get startOffset => _data.startOffset;
  int get endOffset => _data.endOffset;
  html.LIElement get element => _element;
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

  OutlineClass(services.OutlineClass data)
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
      _create(data);
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
