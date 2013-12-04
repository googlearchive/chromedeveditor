library example_page;

import 'dart:html';
import 'package:polymer/polymer.dart';

@CustomTag('example-page')
class ExamplePage extends PolymerElement {
  ExamplePage.created(): super.created();
  menuAction(Event e, var detail, Node target) {
    print("menuAction clicked");
  }
}