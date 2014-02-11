// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.ui.utils.html_utils;

import 'dart:html';

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

  return rect.containsPoint(event.client);
}

/**
 * Cancel the given event by stopping propagation and preventing default action.
 */
void cancelEvent(Event event) {
  event.stopPropagation();
  event.preventDefault();
}

/**
 * Draws a rounded rectangle in a canvas.
 */
void roundRect(CanvasRenderingContext2D ctx, Rectangle rect,
               {int radius: 5, bool fill: false, bool stroke: true}) {
  ctx.beginPath();
  ctx.moveTo(rect.left + radius, rect.top);
  ctx.lineTo(rect.left + rect.width - radius, rect.top);
  ctx.quadraticCurveTo(rect.left + rect.width,
      rect.top,
      rect.left + rect.width,
      rect.top + radius);
  ctx.lineTo(rect.left + rect.width, rect.top + rect.height - radius);
  ctx.quadraticCurveTo(rect.left + rect.width,
      rect.top + rect.height,
      rect.left + rect.width - radius,
      rect.top + rect.height);
  ctx.lineTo(rect.left + radius, rect.top + rect.height);
  ctx.quadraticCurveTo(rect.left,
      rect.top + rect.height,
      rect.left,
      rect.top + rect.height - radius);
  ctx.lineTo(rect.left, rect.top + radius);
  ctx.quadraticCurveTo(rect.left, rect.top, rect.left + radius, rect.top);
  ctx.closePath();
  if (stroke) {
    ctx.stroke();
  }
  if (fill) {
    ctx.fill();
  }
}
