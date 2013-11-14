// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.splitter;

import 'dart:html';
import 'dart:async';
import 'package:polymer/polymer.dart';

@CustomTag('spark-splitter')
class SparkSplitter extends HtmlElement with Polymer, Observable {
  /// Possible values are "left", "right", "up" and "down".
  /// The direction specifies:
  /// 1) whether the split is horizontal or vertical;
  /// 2) which sibling's size will be changed when the splitter is dragged; the
  ///    other sibling is expected to auto-adjust, e.g. using flexbox.
  @observable String direction = 'left';
  /// Locks the split bar so it can't be dragged.
  @observable bool locked = false;

  /// Whether the split view is horizontal or vertical.
  bool _isHorizontal;

  /// The target sibling whose size will be changed when the splitter is
  /// dragged. The other sibling is expected to auto-adjust, e.g. using flexbox.
  HtmlElement _target;
  bool _isTargetNextSibling;
  /// Cached size of the target.
  int _targetSize;

  /// A regular expression to get the integer part of the target's computed size.
  // NOTE: returned target sizes look like "953px" while the mouse is within the
  // app's window, but once it leaves the window, they start looking like
  // "953.0165948px".
  static final _sizeRe = new RegExp("([0-9]+)(\.[0-9]+)?px");

  /// Temporary subsciptions to event streams, active only during dragging.
  StreamSubscription<MouseEvent> _dragSubscr;
  StreamSubscription<MouseEvent> _dragEndSubscr;

  /// Constructor.
  SparkSplitter.created() : super.created() {
    // TODO(sergeygs): Switch to using onDrag* instead of onMouse* once support
    // onDrag* are fixed (as of 2013-11-13 they don't work).
    onMouseDown.listen(dragStart);
    directionChanged();
  }

  /// Triggered when [direction] is externally changed.
  // NOTE: The name must be exactly like this -- do not change.
  void directionChanged() {
    _isHorizontal = direction == 'up' || direction == 'down';
    _isTargetNextSibling = direction == 'right' || direction == 'down';
    _target = _isTargetNextSibling ? nextElementSibling : previousElementSibling;
    classes.toggle('horizontal', _isHorizontal);
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
  void dragStart(MouseEvent e) {
    // Make active regardless of [locked], to appear responsive.
    classes.add('active');

    if (!locked) {
      _cacheTargetSize();
      // NOTE: unlike onMouseDown, listen to onMouseMove and onMouseUp for
      // the entire document; otherwise, once/if the cursor leaves the boundary
      // of our element, the events will stop firing, leaving us in permanent
      // "sticky" dragging state.
      _dragSubscr = document.onMouseMove.listen(drag);
      _dragEndSubscr = document.onMouseUp.listen(dragEnd);
    }
  }

  /// While dragging, update the target's size based on the mouse movement.
  void drag(MouseEvent e) {
    // Recheck [locked], in case it's been changed externally.
    if (!locked) {
      _updateTargetSize(_isHorizontal ? e.movement.y : e.movement.x);
    }
  }

  /// When dragging stops, unsubscribe from monitoring dragging events except
  /// the starting one.
  void dragEnd(MouseEvent e) {
    assert(_dragSubscr != null && _dragEndSubscr != null);
    // Do this regardless of [locked], just to be sure.
    _dragSubscr.cancel();
    _dragSubscr = null;
    _dragEndSubscr.cancel();
    _dragEndSubscr = null;

    classes.remove('active');
  }
}
