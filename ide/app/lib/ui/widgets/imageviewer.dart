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

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:crypto/crypto.dart' show CryptoUtils;
import 'package:mime/mime.dart' as mime;

import '../utils/html_utils.dart';
import '../../editors.dart';
import '../../workspace.dart';

/**
 * A simple image viewer.
 */
class ImageViewer implements Editor {
  /// The image element
  final html.ImageElement _image = new html.ImageElement();

  /// The root element to put the editor in.
  final html.Element _rootElement = new html.DivElement();

  /// Associated file.
  final File _file;

  double _scale = 1.0;
  double _minScale = 1.0;
  double _maxScale = 1.0;
  double _dx = 0.0;
  double _dy = 0.0;

  /// Scrolling zoom factor. Reciprocal to the units of wheel to zoom the
  /// of a factor of two.
  static const double SCROLLING_ZOOM_FACTOR = 0.001;

  ImageViewer(this._file) {
    _image.draggable = false;
    html.window.onResize.listen((_) => resize());
    _rootElement.classes.add('imageeditor-root');
    _rootElement.append(_image);
    _rootElement.onMouseWheel.listen(_handleMouseWheel);
    _rootElement.onScroll.listen((_) => _updateOffset());
    _loadFile();
  }

  _loadFile() {
    _image.onLoad.listen((_) => resize());
    _file.getBytes().then((chrome.ArrayBuffer content) {
      String base64 = CryptoUtils.bytesToBase64(content.getBytes());
      String mimeType = mime.lookupMimeType(_file.name);
      _image.src = 'data:${mimeType};base64,$base64';
    });
  }

  html.Element get element => _rootElement;
  File get file => _file;

  double get _width => _rootElement.clientWidth.toDouble();
  double get _height => _rootElement.clientHeight.toDouble();
  double get _imageWidth => _image.naturalWidth * _scale;
  double get _imageHeight => _image.naturalHeight * _scale;

  /// Constrain the position of the image. If the image can be show totally from
  /// one direction, it should be centered from that direction; otherwise no
  /// whitespace should be shown.
  void _constrain() {
    if (_imageWidth < _width) {
      double left = _width / 2 - _imageWidth / 2 + _dx;
      double right = _width / 2 + _imageWidth / 2 + _dx;
      if (left < 0) {
        _dx -= left;
      } else if (right > _width) {
        _dx -= right - _width;
      } else {
        _dx = 0.0;
      }
    } else {
      double maxDx = (_imageWidth - _width) / 2;
      if (_dx > maxDx) {
        _dx = maxDx;
      }
      else if (_dx < -maxDx) {
        _dx = -maxDx;
      }
    }

    if (_imageHeight < _height) {
      double top = _height / 2 - _imageHeight / 2 + _dy;
      double bottom = _height / 2 + _imageHeight / 2 + _dy;
      if (top < 0) {
        _dy -= top;
      } else if (bottom > _height) {
        _dy -= bottom - _height;
      } else {
        _dy = 0.0;
      }
    } else {
      double maxDy = (_imageHeight - _height) / 2;
      if (_dy > maxDy) {
        _dy = maxDy;
      }
      else if (_dy < -maxDy) {
        _dy = -maxDy;
      }
    }
  }

  /// Update the offset([_dx] and [_dy]) according to the scrolling.
  void _updateOffset() {
    _constrain();

    double left = _width / 2 - _imageWidth / 2 + _dx;
    double top = _height / 2 - _imageHeight / 2 + _dy;

    if (_imageWidth > _width) {
      _dx = -_rootElement.scrollLeft - _width / 2 + _imageWidth / 2;
    }

    if (_imageHeight > _height) {
      _dy = -_rootElement.scrollTop - _height / 2 + _imageHeight / 2;
    }
  }

  void resize() {
    // Initial scale to "fill" the image to the viewport.
    _maxScale = math.min(
        _width / _image.naturalWidth,
        _height / _image.naturalHeight);
    _scale = math.min(1.0, _maxScale);
    _minScale = _scale;
    _maxScale *= 5.0;
    _layout();
  }

  /// Layout the image according to the offset and scale.
  void _layout() {
    _constrain();

    double left = _width / 2 - _imageWidth / 2 + _dx;
    double top = _height / 2 - _imageHeight / 2 + _dy;

    _image.style.width = '${_imageWidth.round()}px';
    _image.style.height = '${_imageHeight.round()}px';

    _image.style.left = '${math.max(0, left.round())}px';
    _rootElement.scrollLeft = math.max(0, -left.round());

    _image.style.top = '${math.max(0, top.round())}px';
    _rootElement.scrollTop = math.max(0, -top.round());
  }

  void _handleMouseWheel(html.WheelEvent e) {
    // Scroll when alt key is pressed.
    if (!e.altKey) return;

    _updateOffset();
    double factor = math.pow(2.0, -e.deltaY * SCROLLING_ZOOM_FACTOR);
    html.Point position = _getEventPosition(e);

    // Scale the image arround the cursor.
    double scale = _scale;
    _scale *= factor;
    if (_scale < _minScale) {
      _scale = _minScale;
    }
    if (_scale > _maxScale) {
      _scale = _maxScale;
    }
    factor = _scale / scale;

    _dx *= factor;
    _dy *= factor;
    factor -= 1.0;
    _dx -= position.x * factor;
    _dy -= position.y * factor;

    _layout();
    cancelEvent(e);
  }

  /// Get the cursor position of the event and map it to the virtual coordinate.
  html.Point _getEventPosition(html.WheelEvent e) {
    int x = e.offset.x;
    int y = e.offset.y;
    html.Element parent = e.target as html.Element;
    while (parent != _rootElement) {
      x += parent.offsetLeft - parent.scrollLeft;
      y += parent.offsetTop - parent.scrollTop;
      parent = parent.offsetParent;
    }
    x -= parent.scrollLeft + _rootElement.clientWidth / 2;
    y -= parent.scrollTop + _rootElement.clientHeight / 2;
    return new html.Point(x, y);
  }

  void focus() {}

  StreamController _dirtyController = new StreamController.broadcast();
  Stream get onDirtyChange => _dirtyController.stream;
  bool get dirty => false;
  Future save() {
    return new Future.value();
  }

  void activate() {}
}
