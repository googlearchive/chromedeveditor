// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This class implements a cell to show a file.
 */

library spark.ui.widgets.fileitem_cell;

import 'dart:html';

import 'listview_cell.dart';
import '../../workspace.dart';

class FileItemCell implements ListViewCell {
  Resource _resource;
  Element _element;
  bool _highlighted;
  bool acceptDrop;

  FileItemCell(this._resource) {
    DocumentFragment template =
        (querySelector('#fileview-filename-template') as TemplateElement).content;
    DocumentFragment templateClone = template.clone(true);
    _element = templateClone.querySelector('.fileview-filename-container');
    _element.querySelector('.filename').text = _resource.name;
    acceptDrop = false;
    updateErrorStatus();
  }

  Element get element => _element;

  set element(Element element) => _element = element;

  bool get highlighted => _highlighted;

  set highlighted(bool value) => _highlighted = value;

  Element get menuElement => _element.querySelector('.menu');

  void updateErrorStatus() {
    _element.classes.removeAll(['warning', 'error']);

    int severity = _resource.findMaxProblemSeverity();

    if (severity == Marker.SEVERITY_ERROR) {
      _element.classes.add('error');
    } else if (severity == Marker.SEVERITY_WARNING) {
      _element.classes.add('warning');
    }
  }
}
