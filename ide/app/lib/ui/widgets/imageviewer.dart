// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * An image viewer.
 */
library spark.editors.image;

import 'dart:async';
import 'dart:html' as html;
import 'dart:math' as math;
import 'package:crypto/crypto.dart' show CryptoUtils;
import 'package:chrome_gen/chrome_app.dart' as chrome;
import '../utils/html_utils.dart';
import '../../workspace.dart';

/**
 * A simple image viewer.
 */
class ImageViewer {
  /// The image element
  final html.ImageElement image = new html.ImageElement();

  /// The root element to put the editor in.
  final html.Element rootElement = new html.DivElement();

  /// Associated file.
  final File file;

  double _scale = 1.0;
  double _dx = 0.0, _dy = 0.0;

  /// Scrolling zoom factor. Reciprocal to the units of wheel to zoom the
  /// of a factor of two.
  static const double SCROLLING_ZOOM_FACTOR = 0.001;

  ImageViewer(this.file) {
    image.draggable = false;
    rootElement.classes.add('imageeditor-root');
    rootElement.append(image);
    rootElement.onMouseWheel.listen(_handleMouseWheel);
    rootElement.onScroll.listen((_) => _updateOffset());
    _loadFile();
  }

  /// Mime type of the file (according to its file name).
  String get mime {
    int dotIndex = file.name.lastIndexOf('.');
    if (dotIndex < 1) return null;
    String ext = file.name.substring(dotIndex + 1);
    if (ext.length < 3) return null;
    ext = ext.toLowerCase();
    switch(ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'png':
        return 'image/png';
      default:
        return null;
    }
  }

  _loadFile() {
    image.title = 'Loading ${file.name}...';
    image.onLoad.listen((_) {
      image.title = '${file.name}. <ALT + Scroll> to zoom.';
      // Initial scale to "fill" the image to the viewport.
      _scale = math.max(1.0, math.min(
          width / image.naturalWidth,
          height / image.naturalHeight));
      layout();
    });
    file.getBytes().then((chrome.ArrayBuffer content) {
      String base64 = CryptoUtils.bytesToBase64(content.getBytes());
      image.src = 'data:${mime};base64,$base64';
    });
  }

  double get width => rootElement.clientWidth.toDouble();
  double get height => rootElement.clientHeight.toDouble();
  double get imageWidth => image.naturalWidth * _scale;
  double get imageHeight => image.naturalHeight * _scale;

  /// Constrain the position of the image. If the image can be show totally from
  /// one direction, it should be centered from that direction; otherwise no
  /// whitespace should be shown.
  void constrain() {
    if (imageWidth < width) {
      double left = width / 2 - imageWidth / 2 + _dx;
      double right = width / 2 - imageWidth / 2 + _dx;
      if (left < 0) {
        _dx -= left;
      } else if (right > width) {
        _dx -= right - width;
      } else {
        _dx = 0.0;
      }
    } else {
      double maxDx = (imageWidth - width) / 2;
      if (_dx > maxDx) _dx = maxDx;
      else if (_dx < -maxDx) _dx = -maxDx;
    }

    if (imageHeight < height) {
      double top = height / 2 - imageHeight / 2 + _dy;
      double bottom = height / 2 - imageHeight / 2 + _dy;
      if (top < 0) {
        _dy -= top;
      } else if (bottom > height) {
        _dy -= bottom - height;
      } else {
        _dy = 0.0;
      }
    } else {
      double maxDy = (imageHeight - height) / 2;
      if (_dy > maxDy) _dy = maxDy;
      else if (_dy < -maxDy) _dy = -maxDy;
    }
  }

  /// Update the offset([_dx] and [_dy]) according to the scrolling.
  void _updateOffset() {
    constrain();

    double left = width / 2 - imageWidth / 2 + _dx;
    double top = height / 2 - imageHeight / 2 + _dy;

    if (imageWidth > width)
      _dx = -rootElement.scrollLeft - width / 2 + imageWidth / 2;

    if (imageWidth > width)
      _dy = -rootElement.scrollTop - height / 2 + imageHeight / 2;
  }

  /// Layout the image according to the offset and scale.
  void layout() {
    constrain();

    double left = width / 2 - imageWidth / 2 + _dx;
    double top = height / 2 - imageHeight / 2 + _dy;

    image.style.width = '${imageWidth.round()}px';
    image.style.height = '${imageHeight.round()}px';

    image.style.left = '${math.max(0, left.round())}px';
    rootElement.scrollLeft = math.max(0, -left.round());

    image.style.top = '${math.max(0, top.round())}px';
    rootElement.scrollTop = math.max(0, -top.round());
  }

  void _handleMouseWheel(html.WheelEvent e) {
    // Scroll when alt key is pressed.
    if (!e.altKey) return;

    _updateOffset();
    double factor = math.pow(2.0, -e.deltaY * SCROLLING_ZOOM_FACTOR);
    html.Point position = _getEventPosition(e);

    // Scale the image arround the cursor.
    double scale = _scale;
    _dx *= factor;
    _dy *= factor;
    _scale *= factor;
    factor -= 1.0;
    _dx -= position.x * factor;
    _dy -= position.y * factor;

    layout();
    cancelEvent(e);
  }

  /// Get the cursor position of the event and map it to the virtual coordinate.
  html.Point _getEventPosition(html.WheelEvent e) {
    int x = e.offset.x;
    int y = e.offset.y;
    html.Element parent = e.target as html.Element;
    while (parent != rootElement) {
      x += parent.offsetLeft - parent.scrollLeft;
      y += parent.offsetTop - parent.scrollTop;
      parent = parent.offsetParent;
    }
    x -= parent.scrollLeft + rootElement.clientWidth / 2;
    y -= parent.scrollTop + rootElement.clientHeight / 2;
    return new html.Point(x, y);
  }
}
