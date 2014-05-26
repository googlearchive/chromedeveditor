// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.markdown;

import 'dart:async';
import 'dart:html' as html;

import 'package:markdown/markdown.dart' show markdownToHtml;

import 'workspace.dart' as workspace;

class Markdown {
  // Parent conatiner
  final html.Element _container;

  // Workspace file
  final workspace.File _file;

  // Preview button.
  html.ButtonElement previewButton;

  // Preview overlay.
  html.DivElement _previewDiv;

  // Is the markdown in preview window open
  bool _visible = false;

  Markdown(this._container, this._file) {
    // Get and clone template for markdown preview content.
    html.DocumentFragment template =
        (html.querySelector('#markdown-template') as
        html.TemplateElement).content;
    html.DocumentFragment templateClone = template.clone(true);
    _previewDiv = templateClone.querySelector('#markdownContent');
    _previewDiv.onMouseWheel.listen((html.MouseEvent event) =>
        event.stopPropagation());

    // Get and clone template for markdown preview button.
    template =
            (html.querySelector('#markdown-preview-button-template') as
            html.TemplateElement).content;
    templateClone = template.clone(true);
    previewButton = templateClone.querySelector('#togglePreviewButton');

    _previewDiv.classes.add('hidden');
    _container.children.add(_previewDiv);

    previewButton.onClick.listen((_) => toggle());
  }

  void toggle() {
    visible = !visible;
    renderHtml();
  }

  void renderHtml() {
    if (visible) {
      _file.getContents().then((String contents) {
        String markdownHtml = markdownToHtml(contents);
        _previewDiv.children.clear();
        _previewDiv.appendHtml(markdownHtml);
      });
    }
  }

  bool get visible => _visible;
  set visible(bool value) {
    _visible = value;
    _previewDiv.classes.toggle('hidden', !_visible);
    previewButton.children.first.classes.toggle('glyphicon-eye-open', !_visible);
    previewButton.children.first.classes.toggle('glyphicon-eye-close', _visible);
  }

  void activate() {
    _container.children.add(_previewDiv);
    _container.children.add(previewButton);
  }

  void deactivate() {
    _container.children.remove(_previewDiv);
    _container.children.remove(previewButton);
  }
}
