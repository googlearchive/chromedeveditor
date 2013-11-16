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

import 'editor.dart';
import '../workspace.dart';

/**
 * This class tracks the state associated with each open editor.
 */
class ImageEditorSession implements EditorSession {
  final File file;
  final EditorSessionManager sessionManager;

  ImageEditor _editor;
  bool _loaded, _loading = false;
  final Completer _loadCompleter = new Completer();

  double _scale = 1.0;
  double dx = 0.0, dy = 0.0;

  ImageEditorSession(this.file, this.sessionManager) {
    _editor = new ImageEditor(this);
    if (mime == null) throw new ArgumentError('Unrecognized file type.');
  }

  bool get dirty => false;

  bool get loaded => _loaded;

  Editor get editor => _editor;

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
        _editor.image.title = file.name;
        _editor.image.onLoad.listen((_) {
          _loadCompleter.complete();
        });
        file.getBytes().then((chrome.ArrayBuffer content) {
          var base64 = CryptoUtils.bytesToBase64(content.getBytes());
          _editor.image.src = 'data:${mime};base64,$base64';
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

  double get width => _editor.rootElement.clientWidth.toDouble();
  double get height => _editor.rootElement.clientHeight.toDouble();
  double get imageWidth => _editor.image.naturalWidth * scale;
  double get imageHeight => _editor.image.naturalHeight * scale;

  void constrain() {
    if (imageWidth < width) {
      double left = width / 2 - imageWidth / 2 + dx;
      double right = width / 2 - imageWidth / 2 + dx;
      if (left < 0) {
        dx -= left;
      } else if (right > width) {
        dx -= right - width;
      } else {
        dx = 0.0;
      }
    }

    if (imageHeight < height) {
      double top = height / 2 - imageHeight / 2 + dy;
      double bottom = height / 2 - imageHeight / 2 + dy;
      if (top < 0) {
        dy -= top;
      } else if (bottom > height) {
        dy -= bottom - height;
      } else {
        dy = 0.0;
      }
    }
  }

  void updateOffset() {
    constrain();

    double left = width / 2 - imageWidth / 2 + dx;
    double top = height / 2 - imageHeight / 2 + dy;

    if (imageWidth > width)
      dx = -_editor.rootElement.scrollLeft - width / 2 + imageWidth / 2;

    if (imageWidth > width)
      dy = -_editor.rootElement.scrollTop - height / 2 + imageHeight / 2;
  }

  void layout() {
    constrain();

    double left = width / 2 - imageWidth / 2 + dx;
    double top = height / 2 - imageHeight / 2 + dy;

    _editor.image.style.width = '${imageWidth.round()}px';
    _editor.image.style.height = '${imageHeight.round()}px';

    _editor.image.style.left = '${math.max(0, left.round())}px';
    _editor.rootElement.scrollLeft = math.max(0, -left.round());

    _editor.image.style.top = '${math.max(0, top.round())}px';
    _editor.rootElement.scrollTop = math.max(0, -top.round());

    sessionManager.persistState();
  }

  Future saveFile() {}

  bool fromMap(Map m, Workspace workspace) {
    File f = workspace.restoreResource(m['file']);
    if (f == null) {
      return false;
    } else {
      dx = m['dx'];
      dy = m['dy'];
      scale = m['scale'];
      return true;
    }
  }

  Map toMap() {
    return {
      'file': file == null ? null : file.path,
      'scale': _scale,
      'dx': dx,
      'dy': dy,
    };
  }
}

class ImageEditor implements Editor {
  final html.ImageElement image = new html.ImageElement();
  ImageEditorSession _session;

  /// The root element to put the editor in.
  final html.Element rootElement = new html.DivElement();

  ImageEditor(this._session) {
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

  /// Gets/sets the current session.
  EditorSession get session => _session;
  set session(EditorSession _) {
    // Do nothing.
  }

  resize() {
    _session.layout();
  }

  void _handleScroll(_) {
    _session.updateOffset();
  }

  void _handleMouseWheel(html.WheelEvent e) {
    var factor = math.pow(0.9, e.deltaY * 3 / 160);
    var position = getEventPosition(e);

    // Scale the image arround the cursor.
    double dx = _session.dx;
    double dy = _session.dy;
    double scale = _session._scale;
    dx *= factor;
    dy *= factor;
    _session._scale *= factor;
    factor -= 1.0;
    dx -= position.x * factor;
    dy -= position.y * factor;
    _session.dx = dx;
    _session.dy = dy;

    _session.layout();
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

class ImageEditorProvider extends DefaultEditorProvider {
  final EditorSessionManager sessionManager;

  ImageEditorProvider(this.sessionManager);

  EditorSession createSession(File file) {
    return new ImageEditorSession(file, sessionManager);
  }
}
