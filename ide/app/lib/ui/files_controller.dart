// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This class implements the controller for the list of files.
 */
library spark.ui.widgets.files_controller;

import 'dart:html';

import 'files_controller_delegate.dart';
import 'widgets/file_item_cell.dart';
import 'widgets/listview.dart';
import 'widgets/listview_cell.dart';
import 'widgets/listview_delegate.dart';
import '../workspace.dart';

class FilesController implements ListViewDelegate {
  ListView _listView;
  Workspace _workspace;
  List<Resource> _files;
  FilesControllerDelegate _delegate;

  FilesController(Workspace workspace, FilesControllerDelegate delegate) {
    _workspace = workspace;
    _delegate = delegate;
    _files = [];
    _listView = new ListView(querySelector('#fileViewArea'), this);

    _workspace.onResourceChange.listen((event) {
      _processEvents(event);
    });
  }

  void selectLastFile() {
    if (_files.isEmpty) {
      return;
    }

    _listView.selection = [_files.length - 1];
    _delegate.openInEditor(_files.last);
  }

  void selectFirstFile() {
    if (_files.isEmpty) {
      return;
    }

    _listView.selection = [0];
    _delegate.openInEditor(_files.last);
  }

  /*
   * Implementation of the [ListViewDelegate] interface.
   */

  int listViewNumberOfRows(ListView view) {
    return _files.length;
  }

  ListViewCell listViewCellForRow(ListView view, int rowIndex) {
    return new FileItemCell(_files[rowIndex].name);
  }

  int listViewHeightForRow(ListView view, int rowIndex) {
    return 20;
  }

  List<Resource> getSelection() {
    List resources = [];
    _listView.selection.forEach((index) {
        resources.add(_files[index]);
     });
    return resources;
  }


  void listViewSelectedChanged(ListView view, List<int> rowIndexes) {
    if (rowIndexes.isEmpty) {
      return;
    }

    _delegate.openInEditor(_files[rowIndexes[0]]);
  }

  void listViewDoubleClicked(ListView view, List<int> rowIndexes) {

  }

  /**
   * Event handler for workspace events.
   */
  void _processEvents(ResourceChangeEvent event) {
    // TODO: process other types of events
    if (event.type == ResourceEventType.ADD) {
      _files.add(event.resource);
      _listView.reloadData();
    }
    if (event.type == ResourceEventType.DELETE) {
      _files.remove(event.resource);
      // TODO: make a more informed selection, maybe before the delete?
      selectLastFile();
      _listView.reloadData();
    }
  }
}
