// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This class implements a cell to show a file.
 */

library spark.ui.widgets.fileitem_cell;

import 'dart:html' hide File;

import 'listview_cell.dart';
import '../../utils.dart';
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
  }

  Element get element => _element;

  set element(Element element) => _element = element;

  bool get highlighted => _highlighted;

  set highlighted(bool value) => _highlighted = value;

  Element get fileNameElement => _element.querySelector('.nameField');

  Element get fileInfoElement => _element.querySelector('.infoField');

  Element get fileStatusElement => _element.querySelector('.fileStatus');

  Element get gitStatusElement => _element.querySelector('.gitStatus');

  void setFileInfo(String infoString) {
    fileInfoElement.innerHtml = infoString;
  }

  void updateFileStatus() {
    Element element = fileStatusElement;
    element.classes.removeAll(['warning', 'error']);

    int severity = resource.findMaxProblemSeverity();

    if (severity == Marker.SEVERITY_ERROR) {
      element.classes.add('error');
    } else if (severity == Marker.SEVERITY_WARNING) {
      element.classes.add('warning');
    }

    // Add classes to display file icons.
    if (resource is Project) {
      // Don't display an icon for projects.

    } else if (resource is Folder) {
      fileNameElement.classes.toggle('typeFolder', true);
    } else if (resource is File) {
      if (isImageFilename(resource.name)) {
        fileNameElement.classes.toggle('typeImageFile', true);
      } else if (isWebLikeFilename(resource.name)) {
        fileNameElement.classes.toggle('typeHtmlFile', true);
      } else if (isTextFilename(resource.name)) {
        fileNameElement.classes.toggle('typeTextFile', true);
      } else {
        fileNameElement.classes.toggle('typeFile', true);
      }
    }
  }

  void setGitStatus({bool dirty: false}) {
    Element element = gitStatusElement;
    element.classes.toggle('dirty', dirty);
  }
}
