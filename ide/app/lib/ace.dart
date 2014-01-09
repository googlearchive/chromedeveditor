// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * An entrypoint to the [ace.dart](https://github.com/rmsmith/ace.dart) package.
 */
library spark.ace;

import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:math' as math;

import 'package:ace/ace.dart' as ace;
import 'package:path/path.dart' as path;

import 'workspace.dart' as workspace;
import 'editors.dart';
import 'preferences.dart';
import 'utils.dart' as utils;

export 'package:ace/ace.dart' show EditSession;

class AceEditor extends Editor {
  final AceContainer aceContainer;

  workspace.File file;

  html.Element get element => aceContainer.parentElement;

  AceEditor(this.aceContainer);

  void resize() => aceContainer.resize();

  void focus() => aceContainer.focus();
}

/**
 * A wrapper around an Ace editor instance.
 */
class AceContainer {
  static final KEY_BINDINGS = ace.KeyboardHandler.BINDINGS;
  // 2 light themes, 4 dark ones.
  static final THEMES = [
      'textmate', 'tomorrow',
      'tomorrow_night', 'monokai', 'idle_fingers', 'pastel_on_dark'
  ];

  /**
   * The container for the Ace editor.
   */
  final html.Element parentElement;

  ace.Editor _aceEditor;

  static bool get available => js.context['ace'] != null;

  StreamSubscription _markerSubscription;
  workspace.File currentFile;

  AceContainer(this.parentElement) {
    _aceEditor = ace.edit(parentElement);
    _aceEditor.renderer.fixedWidthGutter = true;
    _aceEditor.highlightActiveLine = false;
    _aceEditor.printMarginColumn = 80;
    //_aceEditor.setOption('scrollPastEnd', true);
    _aceEditor.readOnly = true;

    // Enable code completion.
    ace.require('ace/ext/language_tools');
    _aceEditor.setOption('enableBasicAutocompletion', true);
    _aceEditor.setOption('enableSnippets', true);

    // Fallback
    theme = THEMES[0];
  }

  void setMarkers(List<workspace.Marker> markers) {
    List<ace.Annotation> annotations = [];

    for (workspace.Marker marker in markers) {
      String annotationType = _convertMarkerSeverity(marker.severity);
      var annotation = new ace.Annotation(
          text: marker.message,
          row: marker.lineNum - 1, // Ace uses 0-based lines.
          type: annotationType);
      annotations.add(annotation);
    }

    currentSession.annotations = annotations;
  }

  void clearMarkers() => currentSession.clearAnnotations();

  String get theme => _aceEditor.theme.name;

  set theme(String value) => _aceEditor.theme = new ace.Theme.named(value);

  Future<String> getKeyBinding() {
    var handler = _aceEditor.keyBinding.keyboardHandler;
    return handler.onLoad.then((_) {
      return KEY_BINDINGS.contains(handler.name) ? handler.name : null;
    });
  }

  void setKeyBinding(String name) {
    var handler = new ace.KeyboardHandler.named(name);
    handler.onLoad.then((_) => _aceEditor.keyBinding.keyboardHandler = handler);
  }

  void focus() => _aceEditor.focus();

  void resize() => _aceEditor.resize(false);

  ace.EditSession createEditSession(String text, String fileName) {
    ace.EditSession session = ace.createEditSession(
        text, new ace.Mode.forFile(fileName));
    _applyCustomSession(session, fileName);
    return session;
  }

  void _applyCustomSession(ace.EditSession session, String fileName) {
    String extention = path.extension(fileName);
    switch (extention) {
      case '.dart':
        session.tabSize = 2;
        session.useSoftTabs = true;
        break;
      default:
        // For now, 2-space for all file types by default. This can be changed
        // in the future.
        session.tabSize = 2;
        session.useSoftTabs = true;
        break;
    }
    // Disable Ace's analysis (this shows up in JavaScript files).
    session.useWorker = false;
  }

  html.Point get cursorPosition {
    ace.Point cursorPosition = _aceEditor.cursorPosition;
    return new html.Point(cursorPosition.column, cursorPosition.row);
  }

  void set cursorPosition(html.Point position) {
    _aceEditor.navigateTo(position.y, position.x);
  }

  ace.EditSession get currentSession => _aceEditor.session;

  void switchTo(ace.EditSession session, [workspace.File file]) {
    if (session == null) {
      _aceEditor.session = ace.createEditSession('', new ace.Mode('ace/mode/text'));
      _aceEditor.readOnly = true;
    } else {
      _aceEditor.session = session;

      if (_aceEditor.readOnly) {
        _aceEditor.readOnly = false;
      }
    }

    // Setup the code completion options for the current file type.
    if (file != null) {
      currentFile = file;
      _aceEditor.setOption(
          'enableBasicAutocompletion', path.extension(file.name) != '.dart');

      // TODO(ericarnold): Markers aren't shown until file is edited.  Fix.
      setMarkers(currentFile.getMarkers());

      if (_markerSubscription == null) {
        _markerSubscription = file.workspace.onMarkerChange.listen(
            _handleMarkerChange);
      }
    }
  }

  void _handleMarkerChange(workspace.MarkerChangeEvent event) {
    // TODO(ericarnold): This gets called repeatedly.  Fix.
    // This should work for both ADD and DELETE events.
    setMarkers(currentFile.getMarkers());
  }

  String _convertMarkerSeverity(int markerSeverity) {
    switch (markerSeverity) {
      case workspace.Marker.SEVERITY_ERROR:
        return ace.Annotation.ERROR;
        break;
      case workspace.Marker.SEVERITY_WARNING:
        return ace.Annotation.WARNING;
        break;
      case workspace.Marker.SEVERITY_INFO:
        return ace.Annotation.INFO;
        break;
    }
  }
}

class ThemeManager {
  AceContainer aceContainer;
  PreferenceStore prefs;
  html.Element _label;

  ThemeManager(this.aceContainer, this.prefs, this._label) {
    prefs.getValue('aceTheme').then((String value) {
      if (value != null) {
        aceContainer.theme = value;
        _updateName(value);
      } else {
        _updateName(aceContainer.theme);
      }
    });
  }

  void inc(html.Event e) {
   e.stopPropagation();
    _changeTheme(1);
  }

  void dec(html.Event e) {
    e.stopPropagation();
    _changeTheme(-1);
  }

  void _changeTheme(int direction) {
    int index = AceContainer.THEMES.indexOf(aceContainer.theme);
    index = (index + direction) % AceContainer.THEMES.length;
    String newTheme = AceContainer.THEMES[index];
    prefs.setValue('aceTheme', newTheme);
    _updateName(newTheme);
    aceContainer.theme = newTheme;
  }

  void _updateName(String name) {
    _label.text = utils.capitalize(name.replaceAll('_', ' '));
  }
}

class KeyBindingManager {
  AceContainer aceContainer;
  PreferenceStore prefs;
  html.Element _label;

  KeyBindingManager(this.aceContainer, this.prefs, this._label) {
    prefs.getValue('keyBinding').then((String value) {
      if (value != null) {
        aceContainer.setKeyBinding(value);
      }
      _updateName(value);
    });
  }

  void inc(html.Event e) {
    e.stopPropagation();
    _changeBinding(1);
  }

  void dec(html.Event e) {
    e.stopPropagation();
    _changeBinding(-1);
  }

  void _changeBinding(int direction) {
    aceContainer.getKeyBinding().then((String name) {
      int index = math.max(AceContainer.KEY_BINDINGS.indexOf(name), 0);
      index = (index + direction) % AceContainer.KEY_BINDINGS.length;
      String newBinding = AceContainer.KEY_BINDINGS[index];
      prefs.setValue('keyBinding', newBinding);
      _updateName(newBinding);
      aceContainer.setKeyBinding(newBinding);
    });
  }

  void _updateName(String name) {
    _label.text =
        'Keys: ' + (name == null ? 'default' : utils.capitalize(name));
  }
}
