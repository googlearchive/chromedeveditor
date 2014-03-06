import 'dart:html' as html;

import '../lib/services/services_common.dart' as data;

class Test {
  Map outlineTopLevelVariableMap = {
      "name": "varName",
      "startOffset": 10,
      "endOffset": 20,
      "type": "top-level-variable"};

  Map outlineClassMap = {
      "name": "className",
      "startOffset": 30,
      "endOffset": 40,
      "abstract": true,
      "members": [],
      "type": "class"};

  Map outlineFunctionMap = {
      "name": "functionName",
      "startOffset": 50,
      "endOffset": 60,
      "type": "function"};

  Map outlineMethodMap = {
      "name": "methodName",
      "startOffset": 70,
      "endOffset": 80,
      "type": "method"};

  Map outlineClassVariableMap = {
      "name": "variableName",
      "startOffset": 90,
      "endOffset": 100,
      "type": "class-variable"};

  data.Outline outline;

  test() {
    data.OutlineTopLevelVariable outlineTopLevelVariable =
        new data.OutlineTopLevelEntry.fromMap(outlineTopLevelVariableMap);

    data.OutlineClass outlineEmptyClass =
        new data.OutlineTopLevelEntry.fromMap(outlineClassMap);

    // Fill the class and re-test
    outlineClassMap['members'].add(outlineClassVariableMap);
    outlineClassMap['members'].add(outlineMethodMap);

    data.OutlineClass outlineClass =
        new data.OutlineTopLevelEntry.fromMap(outlineClassMap);

    data.OutlineTopLevelFunction outlineFunction =
        new data.OutlineTopLevelEntry.fromMap(outlineFunctionMap);
    outline = new data.Outline.fromMap({
      "entries": [outlineTopLevelVariableMap, outlineClassMap, outlineFunctionMap]});
  }
}

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
    _rootList = new html.UListElement();
    _outlineDiv.append(_rootList);
    Test test = new Test();

    test.test();

    populate(test.outline);

//    addClass()
//      ..addMethod()
//      ..addProperty();
//    addVariable();
//    addFunction();
  }

  void populate(data.Outline outline) {
    for (data.OutlineTopLevelEntry model in outline.entries) {
      _create(model);
    }
  }

  OutlineTopLevelItem _create(data.OutlineTopLevelEntry model) {
    if (model is data.OutlineClass) {
      return addClass(model);
    } else if (model is data.OutlineTopLevelVariable) {
      return addVariable(model);
    } else if (model is data.OutlineTopLevelFunction) {
      return addFunction(model);
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

  OutlineTopLevelVariable addVariable(data.OutlineTopLevelVariable model) =>
      _addItem(new OutlineTopLevelVariable(model));
  OutlineTopLevelFunction addFunction(data.OutlineTopLevelFunction model) =>
      _addItem(new OutlineTopLevelFunction(model));

  OutlineClass addClass(data.OutlineClass model) {
    OutlineClass classItem = new OutlineClass(model);
    _addItem(classItem);
    _rootList.append(classItem._childrenRootElement);
    return classItem;
  }
}


abstract class OutlineItem {
  html.LIElement _element;
  data.OutlineEntry _model;

  OutlineItem(this._model) {
    _element = new html.LIElement();
    _element.text = _model.name;
  }
}

abstract class OutlineTopLevelItem extends OutlineItem {
  OutlineTopLevelItem(data.OutlineTopLevelEntry model) : super(model);
}

class OutlineTopLevelVariable extends OutlineTopLevelItem {
  OutlineTopLevelVariable(data.OutlineTopLevelVariable model) : super(model);
}

class OutlineTopLevelFunction extends OutlineTopLevelItem {
  OutlineTopLevelFunction(data.OutlineTopLevelFunction model) : super(model);
}

class OutlineClass extends OutlineTopLevelItem {
  var _childrenRootElement = new html.UListElement();
  List<OutlineClassMember> members = [];

  OutlineClass(data.OutlineClass model) : super(model) {
    populate(model);
  }

  OutlineClassMember _addElement(OutlineClassMember member) {
    _childrenRootElement.append(member._element);
    members.add(member);
    return member;
  }

  void populate(data.OutlineClass classModel) {
    for (data.OutlineEntry model in classModel.members) {
      _create(model);
    }
  }

  OutlineItem _create(data.OutlineEntry model) {
    if (model is data.OutlineMethod) {
      return addMethod(model);
    } else if (model is data.OutlineClassVariable) {
      return addProperty(model);
    } else {
      throw new UnimplementedError("Unknown type");
    }
  }

  OutlineMethod addMethod(data.OutlineMethod model) => _addElement(new OutlineMethod(model));
  OutlineProperty addProperty(data.OutlineClassVariable model) => _addElement(new OutlineProperty(model));
}

class OutlineMethod extends OutlineClassMember {
  OutlineMethod(data.OutlineMethod model) : super(model);
}

abstract class OutlineClassMember extends OutlineItem {
  OutlineClassMember(data.OutlineMember model) : super(model);
}

class OutlineProperty extends OutlineClassMember {
  OutlineProperty(data.OutlineClassVariable model) : super(model);
}

