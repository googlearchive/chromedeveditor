library ui;

import 'dart:html';
import 'package:polymer/polymer.dart';

@CustomTag('example-ui')
class ExampleUi extends PolymerElement {
  final exampleItems = ['dog', 'cat', 'bat'];

  @published int selectedItem = 1;

  factory ExampleUi() => new Element.tag('ExampleUi');

  ExampleUi.created(): super.created();
}
