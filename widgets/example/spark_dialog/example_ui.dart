library ui;

import 'dart:html';
import 'package:polymer/polymer.dart';
import 'package:spark_widgets/spark_dialog/spark_dialog.dart';

@CustomTag('example-ui')
class ExampleUi extends PolymerElement {
  factory ExampleUi() => new Element.tag('ExampleUi');

  ExampleUi.created() : super.created();

  void showDialog() {
    ($['dialog'] as SparkDialog).show();
  }
}
