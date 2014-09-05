// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A library to allow a de-coupled way for [Decorator]s to decorate arbitrary
 * objects with text labels.
 */
library spark.decorators;

import 'dart:async';

/**
 * A class that can decorate an object with a text label.
 */
abstract class Decorator {
  bool canDecorate(Object object);
  String getTextDecoration(Object object);

  Stream get onChanged;
}

/**
 * A class to manage one or more [Decorator]s. Clients can listen on the
 * [onChanged] event to know when they should refresh the text decorations.
 */
class DecoratorManager {
  List<Decorator> _decorators = [];
  StreamController _controller = new StreamController.broadcast();
  Timer _timer;

  DecoratorManager();

  void addDecorator(Decorator decorator){
    _decorators.add(decorator);

    decorator.onChanged.listen((_) => _pingTimer());
  }

  bool canDecorate(Object object) =>
      _decorators.any((d) => d.canDecorate(object));

  String getTextDecoration(Object object) {
    if (object == null) return null;

    String result;

    for (Decorator decorator in _decorators) {
      if (decorator.canDecorate(object)) {
        String dec = decorator.getTextDecoration(object);

        if (dec != null) {
          result = (result == null) ? dec : '${result}, ${dec}';
        }
      }
    }

    return result;
  }

  /**
   * Fired whenever one of the decorators managed by this class changes.
   */
  Stream get onChanged => _controller.stream;

  void _pingTimer() {
    // Consolidate events that happen at approx. the same time.
    if (_timer != null) {
      _timer.cancel();
    }

    _timer = new Timer(new Duration(milliseconds: 50), _fireEvent);
  }

  void _fireEvent() => _controller.add(null);
}
