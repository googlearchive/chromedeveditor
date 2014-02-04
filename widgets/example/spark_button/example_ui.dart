library ui;

import 'dart:html';
import 'package:polymer/polymer.dart';

@CustomTag('example-ui')
class ExampleUi extends PolymerElement {
  factory ExampleUi() => new Element.tag('ExampleUi');

  ExampleUi.created() : super.created();
}
