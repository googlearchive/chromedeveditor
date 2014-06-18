// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This class implements a cell to show a file.
 */

library spark.ui.widgets.fileitem_cell;

import 'dart:html' hide File;

import 'listview_cell.dart';
import '../../workspace.dart';

class FileItemCell implements ListViewCell {
  final Resource resource;
  Element _element;
  bool _highlighted;
  bool acceptDrop;

  FileItemCell(this.resource) {
    DocumentFragment template =
        (querySelector('#fileview-filename-template') as TemplateElement).content;
    DocumentFragment templateClone = template.clone(true);
    _element = templateClone.querySelector('.fileview-filename-container');
    if (resource is Project) {
      _element.classes.add('project');
    }
    fileNameElement.innerHtml = resource.name;
    acceptDrop = false;
    updateFileStatus();

    // Update the node when we're inserted into the tree. Some of the state we
    // modify is contained in parent nodes (the file status).
    element.on['DOMNodeInserted'].listen((e) => updateFileStatus());
  }

  Element get element => _element;

  set element(Element element) => _element = element;

  bool get highlighted => _highlighted;

  set highlighted(bool value) => _highlighted = value;

  Element get fileNameElement => _element.querySelector('.nameField');

  Element get fileInfoElement => _element.querySelector('.infoField');

  Element get fileStatusElement {
    if (_element.parent == null) return null;
    return _element.parent.parent.querySelector('.treeviewcell-status');
  }

  Element get gitStatusElement => _element.querySelector('.gitStatus');

  void setFileInfo(String infoString) {
    fileInfoElement.innerHtml = infoString;
  }

  void updateFileStatus() {
    Element element = fileStatusElement;
    if (element == null) return;

    element.classes.removeAll(['warning', 'error']);

    int severity = resource.findMaxProblemSeverity();

    if (severity == Marker.SEVERITY_ERROR) {
      element.classes.add('error');
      if (resource is Project) {
        element.title = 'This project has errors';
      } else if (resource is Folder) {
        element.title = 'Some files in this folder have errors';
      } else {
        element.title = 'This file has some errors';
      }
    } else if (severity == Marker.SEVERITY_WARNING) {
      element.classes.add('warning');
      if (resource is Project) {
        element.title = 'This project has warnings';
      } else if (resource is Folder) {
        element.title = 'Some files in this folder have warnings';
      } else {
        element.title = 'This file has some warnings';
      }
    }
    else {
      element.title = '';
    }

    if (resource is Project) {
      element.classes.toggle('project', true);
    }
  }

  void setGitStatus({bool dirty: false, bool added: false}) {
    Element element = gitStatusElement;
    element.classes.toggle('dirty', dirty);
    if (dirty) {
      if (resource is Project) {
        element.title = 'Some files in this project have been added or modified';
      } else if (resource is Folder) {
        element.title = 'Some files in this folder have been added or modified';
      } else {
        if (added) {
          element.title = 'This file has been added';
        } else {
          element.title = 'This file has been modified';
        }
      }
    } else {
      element.title = '';
    }
  }
}
