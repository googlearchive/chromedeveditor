// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.markdown;

import 'dart:async';
import 'dart:html' as html;

import 'package:markdown/markdown.dart' show markdownToHtml;

import 'workspace.dart' as workspace;

dynamic get _spark => html.querySelector('spark-polymer-ui');

class Markdown {
  // Parent container.
  final html.Element _container;

  // Workspace file.
  final workspace.File _file;

  // Preview button.
  html.Element _previewButton;
  StreamSubscription _previewButtonSubscription;

  // Preview overlay.
  html.DivElement _previewDiv;

  // Is the markdown in preview window open.
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
    _container.children.add(_previewDiv);

    _previewButton = _spark.$['toggleMarkdownPreviewButton'];

    _applyVisibleValue();
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
    _applyVisibleValue();
  }

  void _applyVisibleValue() {
    _previewDiv.classes.toggle('hidden', !_visible);
  }

  void activate() {
    _container.children.add(_previewDiv);

    _previewButton.classes.toggle('hidden', false);
    _previewButtonSubscription = _previewButton.onClick.listen((_) => toggle());
  }

  void deactivate() {
    _container.children.remove(_previewDiv);
    _previewButton.classes.toggle('hidden', true);
    _previewButtonSubscription.cancel();
  }
}
