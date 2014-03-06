import 'dart:html' as html;

import '../lib/services/services_common.dart' as model;

class Outline {
  html.DivElement _outlineDiv;
  html.UListElement _rootList;

  List<OutlineTopLevelItem> children = [];

  Outline(this._outlineDiv) {
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

  void populate(model.Outline outline) {
    // TODO(ericarnold): Is there anything else that needs to be done to
    //    emsure there are no memory leaks?
    children = [];
    if (_rootList != null) {
      _rootList.remove();
    }

    _rootList = new html.UListElement();
    _outlineDiv.append(_rootList);

    for (model.OutlineTopLevelEntry data in outline.entries) {
      _create(data);
    }
  }

  OutlineTopLevelItem _create(model.OutlineTopLevelEntry data) {
    if (data is model.OutlineClass) {
      return _addClass(data);
    } else if (data is model.OutlineTopLevelVariable) {
      return _addVariable(data);
    } else if (data is model.OutlineTopLevelFunction) {
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

  OutlineTopLevelVariable _addVariable(model.OutlineTopLevelVariable data) =>
      _addItem(new OutlineTopLevelVariable(data));

  OutlineTopLevelFunction _addFunction(model.OutlineTopLevelFunction data) =>
      _addItem(new OutlineTopLevelFunction(data));

  OutlineClass _addClass(model.OutlineClass data) {
    OutlineClass classItem = new OutlineClass(data);
    _addItem(classItem);
    _rootList.append(classItem._childrenRootElement);
    return classItem;
  }
}

abstract class OutlineItem {
  html.LIElement _element;
  model.OutlineEntry _data;

  OutlineItem(this._data) {
    _element = new html.LIElement();
    _element.text = _data.name;
  }
}

abstract class OutlineTopLevelItem extends OutlineItem {
  OutlineTopLevelItem(model.OutlineTopLevelEntry data) : super(data);
}

class OutlineTopLevelVariable extends OutlineTopLevelItem {
  OutlineTopLevelVariable(model.OutlineTopLevelVariable data) : super(data);
}

class OutlineTopLevelFunction extends OutlineTopLevelItem {
  OutlineTopLevelFunction(model.OutlineTopLevelFunction data) : super(data);
}

class OutlineClass extends OutlineTopLevelItem {
  var _childrenRootElement = new html.UListElement();
  List<OutlineClassMember> members = [];

  OutlineClass(model.OutlineClass data) : super(data) {
    populate(data);
  }

  OutlineClassMember _addElement(OutlineClassMember member) {
    _childrenRootElement.append(member._element);
    members.add(member);
    return member;
  }

  void populate(model.OutlineClass classData) {
    for (model.OutlineEntry data in classData.members) {
      _create(data);
    }
  }

  OutlineItem _create(model.OutlineEntry data) {
    if (data is model.OutlineMethod) {
      return addMethod(data);
    } else if (data is model.OutlineClassVariable) {
      return addProperty(data);
    } else {
      throw new UnimplementedError("Unknown type");
    }
  }

  OutlineMethod addMethod(model.OutlineMethod data) =>
      _addElement(new OutlineMethod(data));
  OutlineProperty addProperty(model.OutlineClassVariable data) =>
      _addElement(new OutlineProperty(data));
}

class OutlineMethod extends OutlineClassMember {
  OutlineMethod(model.OutlineMethod data) : super(data);
}

abstract class OutlineClassMember extends OutlineItem {
  OutlineClassMember(model.OutlineMember data) : super(data);
}

class OutlineProperty extends OutlineClassMember {
  OutlineProperty(model.OutlineClassVariable data) : super(data);
}

