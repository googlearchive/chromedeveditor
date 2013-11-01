// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This class is the list of callbacks methods needed for `ListView`.
 */

library spark.ui.widgets.listview_delegate;

import 'listview.dart';
import 'listview_cell.dart';

abstract class ListViewDelegate {
  
  /**
   * The implementation of this method should return the number of items in the
   * list. `view` is the list the callback is called from.
   */
  int listViewNumberOfRows(ListView view);
  
  /**
   * The implementation of this method should return a cell to display the item
   * at the given row `rowIndex`. See [ListViewCell].
   * `view` is the list the callback is called from.
   */
  ListViewCell listViewCellForRow(ListView view, int rowIndex);
  
  /**
   * The implementation of this method should return the height in pixels
   * of the cell at the given row `rowIndex`.
   * `view` is the list the callback is called from.
   */
  int listViewHeightForRow(ListView view, int rowIndex);
  
  /**
   * The implementation of this method will be run when the cell at the given
   * index `rowIndex` is clicked.
   * `view` is the list the callback is called from.
   */
  void listViewSelectedChanged(ListView view, List<int> rowIndexes);
  
  /**
   * The implementation of this method will be run when the cell at the given
   * index `rowIndex` is double-clicked.
   * `view` is the list the callback is called from.
   */
  void listViewDoubleClicked(ListView view, List<int> rowIndexes);
}
