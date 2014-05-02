// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This library defines navigation related functionality.
 */
library spark.navigation;

import 'dart:async';

import 'workspace.dart';

/**
 * A class to handle the history of navigation locations in Spark.
 */
class NavigationManager {
  StreamController<NavigationLocation> _controller = new StreamController.broadcast();

  List<NavigationLocation> _locations = [];
  int _position = -1;

  NavigationLocation get location {
    if (_position >= 0 && _position < _locations.length) {
      return _locations[_position];
    } else {
      return null;
    }
  }

  bool canGoBack() => _position > 0;

  void goBack() {
    if (!canGoBack()) return;
    _position--;
    _controller.add(location);
  }

  bool canGoForward() => (_position + 1) < _locations.length;

  void goForward() {
    if (!canGoForward()) return;
    _position++;
    _controller.add(location);
  }

  void gotoLocation(NavigationLocation newLocation, {bool fireEvent: true}) {
    if (canGoForward()) {
      _locations.removeRange(_position + 1, _locations.length - 1);
    }

    _locations.add(newLocation);
    _position = _locations.length - 1;

    if (fireEvent) {
      _controller.add(location);
    }
  }

  Stream<NavigationLocation> get onNavigate => _controller.stream;
}

/**
 * A navigation location - a [File] and [Span] tuple.
 */
class NavigationLocation {
  final File file;
  final Span selection;

  NavigationLocation(this.file, [this.selection = null]);

  String toString() => selection == null ? '[${file}]' : '[${file}, ${selection}]';
}

/**
 * A `Span` is an offset and length tuple.
 */
class Span {
  final int offset;
  final int length;

  Span(this.offset, [this.length = 0]);

  String toString() => '${offset}:${length}';
}
