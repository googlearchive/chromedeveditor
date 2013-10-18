import 'dart:html';

class FileItemView {
  Element _element;
  
  FileItemView(String path) {
    Element template = document.query('#fileview-filename').content;
    //children[0];
    _element = template.clone(true);
    //print(_element.outerHtml);
    _element.query('.filename').text = path;
    query('#fileViewArea').children.add(_element);
  }
}
