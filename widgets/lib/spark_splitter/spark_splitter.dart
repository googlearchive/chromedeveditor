// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.splitter;

import 'dart:html';
import 'dart:async';

import 'package:polymer/polymer.dart';

import '../common/spark_widget.dart';

typedef void SplitterUpdateFunction(int position);

/// Implements the spark-splitter custom Polymer element.
@CustomTag('spark-splitter')
class SparkSplitter extends SparkWidget {
  /// Possible values are "left", "right", "up" and "down".
  /// The direction specifies:
  /// 1) whether the split is horizontal or vertical;
  /// 2) which sibling will be continuously auto-resized when the splitter is
  ///    dragged.
  @published String direction = 'left';
  /// The split bar has a background image.
  @published bool handle = false;
  /// Locks the split bar so it can't be dragged.
  @published bool locked = false;
  /// Get notified of position changes.
  @published SplitterUpdateFunction onUpdate;
  // Get the thickness size of split bar.
  @published int size = 6;

  /**
   * Return the current splitter location.
   */
  num get targetSize {
    final style = _target.getComputedStyle();
    final sizeStr = _isHorizontal ? style.height : style.width;
    return int.parse(_sizeRe.firstMatch(sizeStr).group(1));
  }

  /**
   * Set the current splitter location.
   */
  set targetSize(num val) {
    final sizeStr = '${val.toInt()}px';
    if (_isHorizontal) {
      _target.style.height = sizeStr;
    } else {
      _target.style.width = sizeStr;
    }
  }

  /// Whether the split view is horizontal or vertical.
  bool _isHorizontal;

  /// The target sibling whose size will be changed when the splitter is
  /// dragged. The other sibling is expected to auto-adjust, e.g. using flexbox.
  HtmlElement _target;
  /// Whether [_target] should be the next or the previous sibling of
  /// the splitter (as determined by [direction], e.g. "left" vs. "right").
  bool _isTargetNextSibling;
  /// Cached size of [_target] for the period of dragging.
  int _targetSize;

  /// A regexp to get the integer part of the target's computed size.
  // NOTE: returned target sizes look like "953px" most of the time,
  // but sometimes they start looking like "953.0165948px" (e.g. when the
  // splitter is dragged to the edge of the app's window).
  static final _sizeRe = new RegExp("([0-9]+)(\.[0-9]+)?px");

  /// Temporary subsciptions to event streams, active only during dragging.
  StreamSubscription<MouseEvent> _trackSubscr;
  StreamSubscription<MouseEvent> _trackEndSubscr;

  /// Constructor.
  SparkSplitter.created() : super.created();

  /// Triggered when the control is first displayed.
  @override
  void enteredView() {
    super.enteredView();

    // TODO(sergeygs): Perhaps switch to using onDrag* instead of onMouse* once
    // support for drag-and-drop in shadow DOM is fixed. It is less important
    // here, because the element is not actually supposed to be dropped onto
    // anything. But if the switch is made, "draggable" for the element should
    // be set as well.
    // See bug https://code.google.com/p/chromium/issues/detail?id=264983.
    onMouseDown.listen(trackStart);
    directionChanged();
  }

  /// Triggered when [direction] is externally changed.
  // NOTE: The name must be exactly like this -- do not change.
  void directionChanged() {
    _isHorizontal = direction == 'up' || direction == 'down';
    _isTargetNextSibling = direction == 'right' || direction == 'down';
    _target =
        _isTargetNextSibling ? nextElementSibling : previousElementSibling;
    classes.toggle('horizontal', _isHorizontal);
    _setThickness();
    if (handle) {
      _addBackgroundHandle();
    }
  }

  void _setThickness() {
    final sizeStr = '${size}px';
    if (_isHorizontal) {
      this.style.height = sizeStr;
      this.style.width = "auto";
    } else {
      this.style.height = "auto";
      this.style.width = sizeStr;
    }
  }

  void _addBackgroundHandle() {
    if (_isHorizontal) {
      classes.add('horizontal-handle');
      classes.remove('vertical-handle');
    } else {
      classes.remove('horizontal-handle');
      classes.add('vertical-handle');
    }
  }

  /// Cache the current size of the target.
  void _cacheTargetSize() {
    final style = _target.getComputedStyle();
    final sizeStr = _isHorizontal ? style.height : style.width;
    _targetSize = int.parse(_sizeRe.firstMatch(sizeStr).group(1));
  }

  /// Update the cached and the actual size of the target.
  void _updateTargetSize(int delta) {
    _targetSize += (_isTargetNextSibling ? -delta : delta);
    final sizeStr = '${_targetSize}px';
    if (_isHorizontal) {
      _target.style.height = sizeStr;
    } else {
      _target.style.width = sizeStr;
    }
  }

  /// When dragging starts, cache the target's size and temporarily subscribe
  /// to necessary events to track dragging.
  void trackStart(MouseEvent e) {
    // Make active regardless of [locked], to appear responsive.
    classes.add('active');

    if (!locked) {
      _cacheTargetSize();
      // NOTE: unlike onMouseDown, monitor onMouseMove and onMouseUp for
      // the entire document; otherwise, once/if the cursor leaves the boundary
      // of our element, the events will stop firing, leaving us in a permanent
      // "sticky" dragging state.
      _trackSubscr = document.onMouseMove.listen(track);
      _trackEndSubscr = document.onMouseUp.listen(trackEnd);
    }
  }

  /// While dragging, update the target's size based on the mouse movement.
  void track(MouseEvent e) {
    // Recheck [locked], in case it's been changed externally in mid-flight.
    if (!locked) {
      _updateTargetSize(_isHorizontal ? e.movement.y : e.movement.x);
    }
  }

  /// When dragging stops, unsubscribe from monitoring dragging events except
  /// the starting one.
  void trackEnd(MouseEvent e) {
    assert(_trackSubscr != null && _trackEndSubscr != null);
    // Do this regardless of [locked]. The only case [locked] can be true here
    // is when it's been changed externally in mid-flight. If it's already true
    // when onMouseDown is fired, these subsciptions (and this event handler!)
    // are not activated in the first place.
    _trackSubscr.cancel();
    _trackSubscr = null;
    _trackEndSubscr.cancel();
    _trackEndSubscr = null;

    if (onUpdate != null) onUpdate(_targetSize);

    // Prevent possible wrong use of the cached value.
    _targetSize = null;

    classes.remove('active');
  }
}
