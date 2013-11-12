// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This class is the interface for cell of the ListView.
 */

library spark.ui.widgets.listview_cell;

import 'dart:html';

abstract class ListViewCell {
  /**
   * HTML Element used to display an item of the list.
   * read-only
   */
  Element element;

  /**
   * Set highlighted to true to highlight the selection of this cell.
   * Override the setter to reflect highlighted state.
   */
  bool highlighted;
}
