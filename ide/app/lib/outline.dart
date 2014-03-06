import 'dart:html' as html;

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
    addClass()
      ..addMethod()
      ..addProperty();
    addVariable();
    addFunction();
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

  OutlineTopLevelVariable addVariable() =>
      _addItem(new OutlineTopLevelVariable());
  OutlineTopLevelFunction addFunction() =>
      _addItem(new OutlineTopLevelFunction());

  OutlineClass addClass() {
    OutlineClass classItem = new OutlineClass();
    _addItem(classItem);
    _rootList.append(classItem._childrenRootElement);
    return classItem;
  }
}


abstract class OutlineItem {
  html.LIElement _element;

  OutlineItem(String text) {
    _element = new html.LIElement();
    _element.text = text;
  }
}

class OutlineTopLevelItem extends OutlineItem {
  OutlineTopLevelItem([String text = "OutlineTopLevelItemView"]) : super(text);
}

class OutlineTopLevelVariable extends OutlineTopLevelItem {
  OutlineTopLevelVariable([String text = "tl variable"]) : super(text);
}

class OutlineTopLevelFunction extends OutlineTopLevelItem {
  OutlineTopLevelFunction([String text = "tl function"]) : super(text);
}

class OutlineClass extends OutlineTopLevelItem {
  var _childrenRootElement = new html.UListElement();
  List<OutlineClassMember> members = [];

  OutlineClass([String text = "classview"]) : super(text);

  OutlineClassMember _addElement(OutlineClassMember member) {
    _childrenRootElement.append(member._element);
    members.add(member);
    return member;
  }

  OutlineMethod addMethod() => _addElement(new OutlineMethod());
  OutlineProperty addProperty() => _addElement(new OutlineProperty());
}

class OutlineMethod extends OutlineClassMember {
  OutlineMethod([String text = "method"]) : super(text);
}

abstract class OutlineClassMember extends OutlineItem {
  OutlineClassMember([String text = "member"]) : super(text);
}

class OutlineProperty extends OutlineClassMember {
  OutlineProperty([String text = "property"]) : super(text);
}

