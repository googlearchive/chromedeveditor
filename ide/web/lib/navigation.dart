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
  bool _pauseNavigation = false;

  void pause() {
    _pauseNavigation = true;
  }

  void resume() {
    _pauseNavigation = false;
  }

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

  /**
   * This method checks if it has the currently closing file in the navigation history
   * If it does it deletes it from the list.
   */
  void removeFile(File file) {
    for (var i = 0; i < _locations.length; i++) {
      if ((_locations[i].file.path == file.path) && (_locations[i].file.name == file.name)) {
        _locations.removeAt(i) ;
        if (_position >= i) {
           _position--;
        }
        i--;
      }
    }

    /*
     * in some cases it might happened that the previous location and the
     * next location in the history are the same. In that case, when the file
     * is deleted, the same file will be in the history on consecutive positions.
     * For that reason I need to delete all entries in the history that
     * represent the same file and are on consecutive positions.
     */
    for (var i = 1; i < _locations.length; i++) {
      if (_locations[i].file == _locations[i-1].file) {
        _locations.removeAt(i);
        if (_position >= i) {
           _position--;
        }
        i--;
      }
    }

    if (_position < 0) {
      if (!_locations.isEmpty) {
        _position = 0;
      } else {
        _position = -1;
      }
    }

    if (_position >= 0 && !_pauseNavigation) {
      _controller.add(_locations[_position]);
    }
  }

  void gotoLocation(NavigationLocation newLocation, {bool fireEvent: true}) {
    NavigationLocation previousLocation = _editorCurrentLocation;
    if (previousLocation == newLocation) return;

    if (canGoForward()) {
      _locations.removeRange(_position + 1, _locations.length);
    }

    if (previousLocation != null) {
      if (_position < _locations.length && _position != -1) {
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
