// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This class encapsulates a file item view in the left panel of the
 * application.
 */
library spark.file_item_view;

import 'dart:html';

import 'workspace.dart';

class FileItemView {
  Element _element;

  FileItemView(Workspace workspace) {
    workspace.onResourceChange.listen((event) {
      _processEvents(event);
    });
  }

  void addFile(String path) {
     // We create an HTML element based on a template.
    DocumentFragment template = querySelector('#fileview-filename').content;
    _element = template.clone(true);
    _element.querySelector('.filename').text = path;
    // We add it to the DOM.
    querySelector('#fileViewArea').children.add(_element);
  }

  void _processEvents(ResourceChangeEvent event) {
    // TODO: process other types of events
    if (event.type == ResourceEventType.ADD) {
      addFile(event.resource.name);
    }
  }
}
