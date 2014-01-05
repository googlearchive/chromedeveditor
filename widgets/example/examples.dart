library examples;

import 'dart:html';
import 'package:polymer/polymer.dart';

@CustomTag('widget-examples')
class Examples extends PolymerElement {
  final links = ['spark-button',
                 'spark-icon',
                 'spark-icon-button',
                 'spark-menu',
                 'spark-menu-button',
                 'spark-menu-item',
                 'spark-overlay',
                 'spark-select',
                 'spark-selection',
                 'spark-selector',
                 'spark-splitter',
                 'spark-toggle-button',
                 'spark-toolbar'];

  factory Examples() => new Element.tag('Examples');

  Examples.created() : super.created();
}
