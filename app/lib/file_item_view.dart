import 'dart:html';

class FileItemView {
  Element _element;
  
  FileItemView(String path) {
    DocumentFragment template = query('#fileview-filename').content;
    _element = template.clone(true);
    _element.query('.filename').text = path;
    query('#fileViewArea').children.add(_element);
  }
}
