// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This library defines navigation related functionality.
 */
library spark.navigation;

import 'dart:async';

import 'workspace.dart';

abstract class NavigationLocationProvider{
  NavigationLocation get navigationLocation;
}

/**
 * A class to handle the history of navigation locations in Spark.
 */
class NavigationManager {
  final NavigationLocationProvider _locationProvider;

  NavigationManager(this._locationProvider);

  StreamController<NavigationLocation> _controller = new StreamController.broadcast();

  List<NavigationLocation> _locations = [];
  int _position = -1;

  NavigationLocation get backLocation {
    int backPosition = _position - 1;
    if (backPosition >= 0 && backPosition < _locations.length) {
      return _locations[backPosition];
    } else {
      return null;
    }
  }

  NavigationLocation get forwardLocation {
    int forwardPosition = _position + 1;
    if (forwardPosition >= 0 && forwardPosition < _locations.length) {
      return _locations[forwardPosition];
    } else {
      return null;
    }
  }

  // For unit tests.
  NavigationLocation get currentLocation {
    if (_position >= 0 && _position < _locations.length) {
      return _locations[_position];
    } else {
      return null;
    }
  }

  NavigationLocation get _editorCurrentLocation =>
      _locationProvider.navigationLocation;

  bool canGoBack() => backLocation != null;

  void goBack() {
    if (!canGoBack()) return;
    _locations[_position] = _editorCurrentLocation;
    _controller.add(backLocation);
    _position--;
  }

  bool canGoForward() => forwardLocation != null;

  void goForward() {
    if (!canGoForward()) return;
    _locations[_position] = _editorCurrentLocation;
    _controller.add(forwardLocation);
    _position++;
  }

  void gotoLocation(NavigationLocation newLocation, {bool fireEvent: true}) {
    NavigationLocation previousLocation = _editorCurrentLocation;
    if (previousLocation == newLocation) return;

    if (canGoForward()) {
      _locations.removeRange(_position + 1, _locations.length);
    }

    if (previousLocation != null) {
      if (_position < _locations.length) {
        _locations[_position] = previousLocation;
      } else {
        _position++;
        _locations.add(previousLocation);
      }
    }
    _position++;
    _locations.add(newLocation);

    if (fireEvent) {
      _controller.add(newLocation);
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

  bool operator==(NavigationLocation other) {
    if (other is! NavigationLocation) return false;
    return file == other.file && selection == other.selection;
  }

  String toString() => selection == null ? '[${file}]' : '[${file}, ${selection}]';
}

/**
 * A `Span` is an offset and length tuple.
 */
class Span {
  final int offset;
  final int length;

  Span(this.offset, [this.length = 0]);

  bool operator==(Span other) {
    if (other is! Span) return false;
    return offset == other.offset && other.length == other.length;
  }

  String toString() => '${offset}:${length}';
}
