
import 'dart:html';

import 'package:chrome/chrome_app.dart' as chrome;

int boundsChange = 100;

/**
 * A `hello world` application for Chrome Apps written in Dart.
 *
 * For more information, see:
 * - http://developer.chrome.com/apps/api_index.html
 * - https://github.com/dart-gde/chrome.dart
 */
void main() {
  querySelector("#text_id").onClick.listen(resizeWindow);
}

void resizeWindow(MouseEvent event) {
  chrome.ContentBounds bounds = chrome.app.window.current().getBounds();

  bounds.width += boundsChange;
  bounds.left -= boundsChange ~/ 2;

  chrome.app.window.current().setBounds(bounds);

  boundsChange *= -1;
}
