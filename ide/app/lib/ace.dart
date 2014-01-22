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

class TextEditor extends Editor {
  final AceManager aceManager;
  final workspace.File file;

  StreamController _dirtyController = new StreamController.broadcast();

  ace.EditSession _session;

  void setSession(ace.EditSession value) {
    _session = value;
    _session.onChange.listen((_) => dirty = true);
  }

  bool _dirty = false;

  TextEditor(this.aceManager, this.file);

  bool get dirty => _dirty;

  Stream get onDirtyChange => _dirtyController.stream;

  set dirty(bool value) {
    if (value != _dirty) {
      _dirty = value;
      _dirtyController.add(value);
    }
  }

  html.Element get element => aceManager.parentElement;

  void activate() {
    // TODO:

  }

  void resize() => aceManager.resize();

  void focus() => aceManager.focus();

  Future save() {
    if (_dirty) {
      return file.setContents(_session.value).then((_) => dirty = false);
    } else {
      return new Future.value();
    }
  }
}

/**
 * A wrapper around an Ace editor instance.
 */
class AceManager {
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

  workspace.Marker _currentMarker;

  StreamSubscription<ace.FoldChangeEvent> _foldListenerSubscription;

  static bool get available => js.context['ace'] != null;

  StreamSubscription _markerSubscription;
  workspace.File currentFile;

  AceManager(this.parentElement) {
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

  html.Element get _editorElement => parentElement.parent;

  html.Element get _minimapElement {
    List<html.Node> minimapElements =
        _editorElement.getElementsByClassName("minimap");
    if (minimapElements.length == 1) {
      return minimapElements.first;
    }

    return null;
  }

  void setMarkers(List<workspace.Marker> markers) {
    List<ace.Annotation> annotations = [];
    int numberLines = currentSession.screenLength;

    _recreateMiniMap();

    for (workspace.Marker marker in markers) {
      String annotationType = _convertMarkerSeverity(marker.severity);
      var annotation = new ace.Annotation(
          text: marker.message,
          row: marker.lineNum - 1, // Ace uses 0-based lines.
          type: annotationType);
      annotations.add(annotation);

      // TODO(ericarnold): This won't update on code folds.  Fix
      // TODO(ericarnold): This should also be based upon annotations so ace's
      //     immediate handling of deleting / adding lines gets used.
      double markerPos =
          currentSession.documentToScreenRow(marker.lineNum, 0) / numberLines * 100.0;

      html.Element minimapMarker = new html.Element.div();
      minimapMarker.classes.add("minimap-marker ${marker.severityDescription}");
      minimapMarker.style.top = '${markerPos.toStringAsFixed(2)}%';
      minimapMarker.onClick.listen((_) => _miniMapMarkerClicked(marker));

      _minimapElement.append(minimapMarker);
    }

    currentSession.setAnnotations(annotations);
  }

  void selectNextMarker() {
    _selectMarkerFromCurrent(1);
  }

  void selectPrevMarker() {
    _selectMarkerFromCurrent(-1);
  }

  void _selectMarkerFromCurrent(int offset) {
    // TODO(ericarnold): This should be based upon the current cursor position.
    List<workspace.Marker> markers = currentFile.getMarkers();
    if (markers != null && markers.length > 0) {
      if (_currentMarker == null) {
        _selectMarker(markers[0]);
      } else {
        int markerIndex = markers.indexOf(_currentMarker);
        markerIndex += offset;
        if (markerIndex < 0) {
          markerIndex = markers.length -1;
        } else if (markerIndex >= markers.length) {
          markerIndex = 0;
        }
        _selectMarker(markers[markerIndex]);
      }
    }
  }

  void _miniMapMarkerClicked(workspace.Marker marker) {
    _selectMarker(marker);
  }

  void _selectMarker(workspace.Marker marker) {
    // TODO(ericarnold): Marker range should be selected, but we either need
    // Marker to include col info or we need a way to convert col to char-pos
    _aceEditor.gotoLine(marker.lineNum);
    _currentMarker = marker;
  }

  void _recreateMiniMap() {
    html.Element scrollbarElement =
        _editorElement.getElementsByClassName("ace_scrollbar").first;
    if (scrollbarElement.style.right != "10px") {
      scrollbarElement.style.right = "10px";
    }

    html.Element miniMap = new html.Element.div();
    miniMap.classes.add("minimap");

    if (_minimapElement != null) {
      _minimapElement.replaceWith(miniMap);
    } else {
      _editorElement.append(miniMap);
    }
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
    if (_foldListenerSubscription != null) {
      _foldListenerSubscription.cancel();
      _foldListenerSubscription = null;
    }

    if (session == null) {
      _aceEditor.session = ace.createEditSession('', new ace.Mode('ace/mode/text'));
      _aceEditor.readOnly = true;
    } else {
      _aceEditor.session = session;

      if (_aceEditor.readOnly) {
        _aceEditor.readOnly = false;
      }

      _foldListenerSubscription = currentSession.onChangeFold.listen((_) {
        setMarkers(file.getMarkers());
      });

      // TODO(ericarnold): Markers aren't shown until file is edited.  Fix.
      setMarkers(file.getMarkers());
    }

    // Setup the code completion options for the current file type.
    if (file != null) {
      currentFile = file;
      _aceEditor.setOption(
          'enableBasicAutocompletion', path.extension(file.name) != '.dart');

      if (_markerSubscription == null) {
        _markerSubscription = file.workspace.onMarkerChange.listen(
            _handleMarkerChange);
      }
    }
  }

  void _handleMarkerChange(workspace.MarkerChangeEvent event) {
    if (event.hasChangesFor(currentFile)) {
      setMarkers(currentFile.getMarkers());
    }
  }

  String _convertMarkerSeverity(int markerSeverity) {
    switch (markerSeverity) {
      case workspace.Marker.SEVERITY_ERROR:
        return ace.Annotation.ERROR;
      case workspace.Marker.SEVERITY_WARNING:
        return ace.Annotation.WARNING;
      case workspace.Marker.SEVERITY_INFO:
        return ace.Annotation.INFO;
    }
  }
}

class ThemeManager {
  AceManager aceManager;
  PreferenceStore prefs;
  html.Element _label;

  ThemeManager(this.aceManager, this.prefs, this._label) {
    prefs.getValue('aceTheme').then((String value) {
      if (value != null) {
        aceManager.theme = value;
        _updateName(value);
      } else {
        _updateName(aceManager.theme);
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
    int index = AceManager.THEMES.indexOf(aceManager.theme);
    index = (index + direction) % AceManager.THEMES.length;
    String newTheme = AceManager.THEMES[index];
    prefs.setValue('aceTheme', newTheme);
    _updateName(newTheme);
    aceManager.theme = newTheme;
  }

  void _updateName(String name) {
    _label.text = utils.toTitleCase(name.replaceAll('_', ' '));
  }
}

class KeyBindingManager {
  AceManager aceManager;
  PreferenceStore prefs;
  html.Element _label;

  KeyBindingManager(this.aceManager, this.prefs, this._label) {
    prefs.getValue('keyBinding').then((String value) {
      if (value != null) {
        aceManager.setKeyBinding(value);
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
    aceManager.getKeyBinding().then((String name) {
      int index = math.max(AceManager.KEY_BINDINGS.indexOf(name), 0);
      index = (index + direction) % AceManager.KEY_BINDINGS.length;
      String newBinding = AceManager.KEY_BINDINGS[index];
      prefs.setValue('keyBinding', newBinding);
      _updateName(newBinding);
      aceManager.setKeyBinding(newBinding);
    });
  }

  void _updateName(String name) {
    _label.text = (name == null ? 'Default' : utils.capitalize(name));
  }
}
