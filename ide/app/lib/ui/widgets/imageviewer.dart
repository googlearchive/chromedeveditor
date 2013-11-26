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

import '../../workspace.dart';

class ImageViewer {
  final html.ImageElement image = new html.ImageElement();

  /// The root element to put the editor in.
  final html.Element rootElement = new html.DivElement();

  final File file;

  bool _loaded, _loading = false;
  final Completer _loadCompleter = new Completer();

  double _scale = 1.0;
  double _dx = 0.0, _dy = 0.0;

  ImageViewer(this.file) {
    image.draggable = false;
    rootElement.classes.add('imageeditor-root');
    rootElement.append(image);
    rootElement.onMouseWheel.listen(_handleMouseWheel);
    rootElement.onScroll.listen(_handleScroll);
  }

  /// Indicates whether the editor is readonly.
  bool get readOnly => true;
  set readOnly(bool _) {
    // Do nothing.
  }

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
      case 'bmp':
        return 'image/bmp';
      case 'tiff':
        return 'image/tiff';
      default:
        return null;
    }
  }

  Future loadFile() {
    if (_loaded) {
      return new Future.value();
    } else {
      if (!_loading) {
        _loading = true;
        image.title = 'Loading ${file.name}...';
        image.onLoad.listen((_) {
          image.title = '${file.name}';
          _scale = math.min(width / image.naturalWidth, height / image.naturalHeight);
          layout();
          _loadCompleter.complete();
        });
        file.getBytes().then((chrome.ArrayBuffer content) {
          var base64 = CryptoUtils.bytesToBase64(content.getBytes());
          image.src = 'data:${mime};base64,$base64';
        });
      }
      return _loadCompleter.future;
    }
  }

  double get scale => _scale;
  set scale (double value) {
    _scale = value;
    layout();
  }

  double get width => rootElement.clientWidth.toDouble();
  double get height => rootElement.clientHeight.toDouble();
  double get imageWidth => image.naturalWidth * scale;
  double get imageHeight => image.naturalHeight * scale;

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
    }
  }

  void updateOffset() {
    constrain();

    double left = width / 2 - imageWidth / 2 + _dx;
    double top = height / 2 - imageHeight / 2 + _dy;

    if (imageWidth > width)
      _dx = -rootElement.scrollLeft - width / 2 + imageWidth / 2;

    if (imageWidth > width)
      _dy = -rootElement.scrollTop - height / 2 + imageHeight / 2;
  }


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

  void _handleScroll(_) {
    updateOffset();
  }

  void _handleMouseWheel(html.WheelEvent e) {
    if (!e.altKey)
      return;

    var factor = math.pow(0.9, e.deltaY * 3 / 160);
    var position = getEventPosition(e);

    // Scale the image arround the cursor.
    double dx = _dx;
    double dy = _dy;
    double scale = _scale;
    dx *= factor;
    dy *= factor;
    _scale *= factor;
    factor -= 1.0;
    dx -= position.x * factor;
    dy -= position.y * factor;
    _dx = dx;
    _dy = dy;

    layout();
    e.preventDefault();
    e.stopPropagation();
  }

  html.Point getEventPosition(html.WheelEvent e) {
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
