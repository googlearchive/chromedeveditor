// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.utils;

import 'dart:html';

int getAbsolutePosition(Element element) {
  Point result = new Point();
  while (element != null) {
    result += element.offset.topLeft;
    element = element.offsetParent;
  }
  return result;
}

int getEventAbsolutePosition(MouseEvent event) {
  return getAbsolutePosition(event.target) + event.offset;
}

int isMouseLocationInElement(MouseEvent event,
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
