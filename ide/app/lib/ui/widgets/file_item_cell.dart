// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This class implements a cell to show a file.
 */

library spark.ui.widgets.fileitem_cell;

import 'dart:html';

import 'listview_cell.dart';

class FileItemCell implements ListViewCell {
  Element _element;
  Element _container;
  bool _highlighted;
  bool acceptDrop;

  FileItemCell(String name) {
    DocumentFragment template =
        (querySelector('#fileview-filename-template') as TemplateElement).content;
    Element templateClone = template.clone(true);
    _element = templateClone.querySelector('.fileview-filename-container');
    _element.querySelector('.filename').text = name;
    acceptDrop = false;
  }

  Element get element => _element;

  set element(Element element) => _element = element;

  bool get highlighted => _highlighted;

  set highlighted(bool value) => _highlighted = value;

  Element get container => _container;

  set container(Element container) => _container = container;
}
