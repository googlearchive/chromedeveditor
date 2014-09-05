// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.ui.widgets.listview_row;

import 'dart:html';

import 'listview_cell.dart';

/**
 * The list of cells of the `ListView` will be stored as a list of
 * `ListViewRow`.
 * Each item will store a cell and a container element.
 */

class ListViewRow {
  ListViewCell cell;
  Element container;
  // y is the vertical position of the row.
  int y;
  // height is the height of the row.
  int height;
  // separator can be null, which means that there's no separator before this
  // row. In this case, separatorY = y and separatorHeight is 0.
  Element separator;
  int separatorY;
  int separatorHeight;
}
