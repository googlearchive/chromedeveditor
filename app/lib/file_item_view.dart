// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:html';

library spark.file_item_view;

/**
 * This class encapsulates a file item view in the left panel of the
 * application.
 */

class FileItemView {
  Element _element;
  
  FileItemView(String path) {
    // We create an HTML element based on a template.
    DocumentFragment template = query('#fileview-filename').content;
    _element = template.clone(true);
    _element.query('.filename').text = path;
    // We add it to the DOM.
    query('#fileViewArea').children.add(_element);
  }
}
