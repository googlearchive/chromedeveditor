library examples;

import 'dart:html';
import 'package:polymer/polymer.dart';

@CustomTag('widget-examples')
class Examples extends PolymerElement {
  final links = ['spark_button',
                 'spark_icon',
                 'spark_icon_button',
                 'spark_menu',
                 'spark_menu_button',
                 'spark_menu_item',
                 'spark_overlay',
                 'spark_selection',
                 'spark_selector',
                 'spark_splitter',
                 'spark_toggle_button',
                 'spark_toolbar'];

  factory Examples() => new Element.tag('Examples');

  Examples.created() : super.created();
}
