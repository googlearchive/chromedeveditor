library ui;

import 'dart:html';

import 'package:polymer/polymer.dart';
import 'package:spark_widgets/spark_menu_button/spark_menu_button.dart';

@CustomTag('example-ui')
class ExampleUi extends PolymerElement {
  factory ExampleUi() => new Element.tag('ExampleUi');

  SparkMenuButton _menuButton;

  ExampleUi.created() : super.created();
}
