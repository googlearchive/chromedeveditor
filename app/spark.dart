
library spark;

import 'dart:async';
import 'dart:html';
import 'dart:js' as jsx;

import 'package:chrome/app.dart' as chrome;

import 'lib/utils.dart';

void main() {
  Spark spark = new Spark();
}

class Spark {

  Spark() {
    document.title = appName;
    print(appName);

    ParagraphElement p = new ParagraphElement();
    p.innerHtml = appName;
    p.style.fontSize = '36pt';
    p.style.marginTop = '100px';
    p.style.textAlign = 'center';
    p.style.color = '#999999';
    p.style.fontFamily = '"Helvetica Neue", Helvetica, Arial, sans-serif';
    p.style.textShadow = '0 1px 2px';
    document.body.children.add(p);

    chrome.app.window.current.onClosed.listen(handleWindowClosed);
  }

  String get appName => i18n('app_name');

  void handleWindowClosed(data) {
    // TODO:
    //print('handleWindowClosed');
  }
}
