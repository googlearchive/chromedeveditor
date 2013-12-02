import 'dart:html';
import 'package:polymer/polymer.dart';
import 'package:spark_widgets/spark-overlay/spark-overlay.dart';

// TODO(terry): Hack to work around lightdom and event.path not quite working.
@CustomTag('spark-ui')
class SparkUi extends PolymerElement {
  factory SparkUi() => new Element.tag('SparkUi');

  SparkUi.created() : super.created();

//  ShadowRoot get _shadowRoot => getShadowRoot('spark-ui');
}
