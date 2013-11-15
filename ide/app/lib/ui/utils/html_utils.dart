// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.ui.utils.html_utils;

import 'dart:html';

/**
 *  Returns position of the element within the page.
 */
Point getAbsolutePosition(Element element) {
  Point result = new Point(0, 0);
  while (element != null) {
    result += element.offset.topLeft;
    element = element.offsetParent;
  }
  return result;
}

/**
 * Returns position of the mouse cursor within the page
 */
Point getEventAbsolutePosition(MouseEvent event) {
  return getAbsolutePosition(event.target) + event.offset;
}

/**
 * Returns true if the mouse cursor is inside an element.
 * `marginX` and `marginY` will define a vertical and horizontal margin to
 * increase the size of the matching area.
 */
bool isMouseLocationInElement(MouseEvent event,
                              Element element,
                              int marginX,
                              int marginY) {
  var rect = element.getBoundingClientRect();
  int width = rect.width + marginX * 2;
  int left = rect.left - marginX;
  int height = rect.height + marginY * 2;
  int top = rect.top - marginY;
  rect = new Rectangle(left, top, width, height);

  var location = getEventAbsolutePosition(event);
  return rect.containsPoint(location);
}

/**
 * Cancel the given event by stopping propagation and preventing default action.
 */
void cancelEvent(Event event) {
  event.stopPropagation();
  event.preventDefault();
}
