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

  FileItemCell(String name) {
    DocumentFragment template =
        (querySelector('#fileview-filename') as TemplateElement).content;
    Element element = template.clone(true);
    _element = new DivElement();
    _element.children.add(element);
    _element.querySelector('.filename').text = name;
  }

  Element get element {
    return _element;
  }

  set element(Element element) {
    _element = element;
  }

  set highlighted(value) {
    _highlighted = value;
  }

  bool get highlighted {
    return _highlighted;
  }

  Element get container {
    return _container;
  }

  set container(Element container) {
    _container = container;
  }
}
