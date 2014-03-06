import 'dart:html' as html;

import '../lib/services.dart' as services;

class Outline {
  html.DivElement _outlineDiv;
  html.UListElement _rootList;
  services.AnalyzerService analyzer;

  List<OutlineTopLevelItem> children = [];

  Outline(services.Services services, this._outlineDiv) {
    analyzer = services.getService("analyzer");

    _outlineDiv.style
        ..position = 'absolute'
        ..width = '200px'
        ..right = '10px'
        ..top ='10px'
        ..bottom = '10px'
        ..background = 'rgb(100, 100, 100)'
        ..borderRadius = '2px'
        ..zIndex = '100'
        ..opacity = '0.6';
  }

  void build(String code) {
    analyzer.getOutlineFor(code).then((services.Outline model) {
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
    _outlineDiv.append(_rootList);

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


  void toggle() {
    if (_outlineDiv.style.display == 'none') {
      _outlineDiv.style.display = 'block';
    } else {
      _outlineDiv.style.display = 'none';
    }
  }

  OutlineTopLevelItem _addItem(OutlineTopLevelItem item) {
    _rootList.append(item._element);
    children.add(item);
    return item;
  }

  OutlineTopLevelVariable _addVariable(services.OutlineTopLevelVariable data) =>
      _addItem(new OutlineTopLevelVariable(data));

  OutlineTopLevelFunction _addFunction(services.OutlineTopLevelFunction data) =>
      _addItem(new OutlineTopLevelFunction(data));

  OutlineClass _addClass(services.OutlineClass data) {
    OutlineClass classItem = new OutlineClass(data);
    _addItem(classItem);
    _rootList.append(classItem._childrenRootElement);
    return classItem;
  }
}

abstract class OutlineItem {
  html.LIElement _element;
  services.OutlineEntry _data;

  OutlineItem(this._data) {
    _element = new html.LIElement();
    _element.text = _data.name;
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
  var _childrenRootElement = new html.UListElement();
  List<OutlineClassMember> members = [];

  OutlineClass(services.OutlineClass data) : super(data) {
    _populate(data);
  }

  OutlineClassMember _addElement(OutlineClassMember member) {
    _childrenRootElement.append(member._element);
    members.add(member);
    return member;
  }

  void _populate(services.OutlineClass classData) {
    for (services.OutlineEntry data in classData.members) {
      _create(data);
    }
  }

  OutlineItem _create(services.OutlineEntry data) {
    if (data is services.OutlineMethod) {
      return addMethod(data);
    } else if (data is services.OutlineClassVariable) {
      return addProperty(data);
    } else {
      throw new UnimplementedError("Unknown type");
    }
  }

  OutlineMethod addMethod(services.OutlineMethod data) =>
      _addElement(new OutlineMethod(data));
  OutlineProperty addProperty(services.OutlineClassVariable data) =>
      _addElement(new OutlineProperty(data));
}

class OutlineMethod extends OutlineClassMember {
  OutlineMethod(services.OutlineMethod data) : super(data);
}

abstract class OutlineClassMember extends OutlineItem {
  OutlineClassMember(services.OutlineMember data) : super(data);
}

class OutlineProperty extends OutlineClassMember {
  OutlineProperty(services.OutlineClassVariable data) : super(data);
}

