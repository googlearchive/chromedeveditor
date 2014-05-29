library ui;

import 'dart:html';
import 'package:polymer/polymer.dart';

@CustomTag('example-ui')
class ExampleUi extends PolymerElement {
  @observable String message = '';

  factory ExampleUi() => new Element.tag('ExampleUi');

  ExampleUi.created() : super.created();

  @override
  void enteredView() {
    super.enteredView();
  }

  void activateHandler(CustomEvent e) {
    message = "You've clicked `${e.detail['value']}`";
    deliverChanges();
  }
}
