library examples;

import 'package:polymer/polymer.dart';

@CustomTag('widget-examples')
class Examples extends PolymerElement {
  final links = ['spark_button',
                 'spark_icon',
                 'spark_menu',
                 'spark_menu_button',
                 'spark_menu_item',
                 'spark_overlay',
                 'spark_selector',
                 'spark_split_view',
                 'spark_splitter',
                 'spark_toggle_button',
                 'spark_toolbar'];

  Examples.created() : super.created();
}
