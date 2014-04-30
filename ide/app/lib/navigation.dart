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
 * TODO:
 */
class NavigationManager {
  StreamController<NavigationLocation> _controller = new StreamController.broadcast();

  List _locations = [];
  int _position = -1;

  NavigationLocation get location {
    if (_position >= 0 && _position < _locations.length) {
      return _locations[_position];
    } else {
      return null;
    }
  }

  bool canNavigate({bool forward: true}) {
    if (forward) {
      return (_position + 1) < _locations.length;
    } {
      return _position > 0;
    }
  }

  void navigate({bool forward: true}) {
    if (!canNavigate(forward: forward)) return;

    forward ? _position++ : _position--;

    _controller.add(location);
  }

  void addLocation(NavigationLocation newLocation, {bool fireEvent: true}) {
    if (canNavigate(forward: true)) {
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
  final Span span;

  NavigationLocation(this.file, this.span);
}

/**
 * A `Span` is an offset and length tuple.
 */
class Span {
  final int offset;
  final int length;

  Span(this.offset, this.length);
}
