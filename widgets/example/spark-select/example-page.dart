library example_page;

import 'package:polymer/polymer.dart';

@CustomTag('example-page')
class ExamplePage extends PolymerElement {
  final List<String> exampleItems = toObservable(<String>['dog', 'cat', 'bat']);
  @published int selectedItem = 1;
  ExamplePage.created(): super.created();
}
