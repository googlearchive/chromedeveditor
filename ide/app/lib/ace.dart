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
import 'package:ace/proxy.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as path;

import '../spark_flags.dart';
import 'css/cssbeautify.dart';
import 'editors.dart';
import 'navigation.dart';
import 'package_mgmt/bower_properties.dart';
import 'package_mgmt/pub.dart';
import 'platform_info.dart';
import 'preferences.dart';
import 'utils.dart' as utils;
import 'workspace.dart' as workspace;
import 'services.dart' as svc;
import 'outline.dart';
import 'ui/polymer/goto_line_view/goto_line_view.dart';

export 'package:ace/ace.dart' show EditSession;

class TextEditor extends Editor {
  static final RegExp whitespaceRegEx = new RegExp('[\t ]*\$', multiLine:true);

  final AceManager aceManager;
  final workspace.File file;

  StreamSubscription _aceSubscription;
  StreamController _dirtyController = new StreamController.broadcast();
  StreamController _modificationController = new StreamController.broadcast();

  ace.EditSession _session;

  String _lastSavedHash;

  bool _dirty = false;

  factory TextEditor(AceManager aceManager, workspace.File file) {
    if (DartEditor.isDartFile(file)) {
      return new DartEditor._create(aceManager, file);
    }
    if (CssEditor.isCssFile(file)) {
      return new CssEditor._create(aceManager, file);
    }
    return new TextEditor._create(aceManager, file);
  }

  TextEditor._create(this.aceManager, this.file);

  void setSession(ace.EditSession value) {
    _session = value;
    _aceSubscription = _session.onChange.listen((_) => dirty = true);
  }

  bool get dirty => _dirty;

  Stream get onDirtyChange => _dirtyController.stream;
  Stream get onModification => _modificationController.stream;

  set dirty(bool value) {
    if (value != _dirty) {
      _dirty = value;
      _dirtyController.add(value);
    }
    _modificationController.add(dirty);
  }

  html.Element get element => aceManager.parentElement;

  void activate() {
    aceManager.outline.visible = supportsOutline;
    aceManager._aceEditor.readOnly = readOnly;
  }

  void deactivate() { }

  void resize() => aceManager.resize();

  void focus() => aceManager.focus();

  void select(Span selection) {
    // Check if we're the current editor.
    if (file != aceManager.currentFile) return;

    ace.Point startSelection = _session.document.indexToPosition(selection.offset);
    ace.Point endSelection = _session.document.indexToPosition(
        selection.offset + selection.length);

    aceManager._aceEditor.gotoLine(startSelection.row);

    ace.Selection aceSel = aceManager._aceEditor.selection;
    aceSel.setSelectionAnchor(startSelection.row, startSelection.column);
    aceSel.selectTo(endSelection.row, endSelection.column);
  }

  bool get supportsOutline => false;

  bool get supportsFormat => false;

  // TODO(ussuri): use MetaPackageManager instead when it's ready.
  bool get readOnly => pubProperties.isInPackagesFolder(file) ||
      bowerProperties.isInPackagesFolder(file);

  void format() { }

  void navigateToDeclaration() { }

  void fileContentsChanged() {
    if (_session != null) {
      // Check that we didn't cause this change event.
      file.getContents().then((String text) {
        String fileContentsHash = _calcMD5(text);

        if (fileContentsHash != _lastSavedHash) {
          _lastSavedHash = fileContentsHash;
          _replaceContents(text);
        }
      });
    }
  }

  Future save([bool stripWhitespace = false]) {
    // We store a hash of the contents when saving. When we get a change
    // notification (in fileContentsChanged()), we compare the last write to the
    // contents on disk.
    if (_dirty) {
      // Remove the trailing whitespace if asked to do so.
      // TODO(ericarnold): Can't think of an easy way to share this preference,
      //           but it might be a good idea to do so rather than passing it.

      String text = _session.value;
      if (stripWhitespace) text = text.replaceAll(whitespaceRegEx, '');
      _lastSavedHash = _calcMD5(text);

      // TODO(ericarnold): Need to cache or re-analyze on file switch.
      // TODO(ericarnold): Need to analyze on initial file load.
      aceManager.buildOutline();

      return file.setContents(text).then((_) => dirty = false);
    } else {
      return new Future.value();
    }
  }

  /**
   * Replace the editor's contents with the given text. Make sure that we don't
   * fire a change event.
   */
  void _replaceContents(String newContents) {
    _aceSubscription.cancel();

    try {
      // Restore the cursor position and scroll location.
      int scrollTop = _session.scrollTop;
      html.Point cursorPos = null;
      if (aceManager.currentFile == file) {
        cursorPos = aceManager.cursorPosition;
      }
      _session.value = newContents;
      _session.scrollTop = scrollTop;
      if (cursorPos != null) {
        aceManager.cursorPosition = cursorPos;
      }
    } finally {
      _aceSubscription = _session.onChange.listen((_) => dirty = true);
    }
  }
}

class DartEditor extends TextEditor {
  static bool isDartFile(workspace.File file) => file.name.endsWith('.dart');

  DartEditor._create(AceManager aceManager, workspace.File file) :
      super._create(aceManager, file);

  bool get supportsOutline => true;

  void navigateToDeclaration() {
    int offset = _session.document.positionToIndex(
        aceManager._aceEditor.cursorPosition);

    aceManager._analysisService.getDeclarationFor(file, offset).then(
        (svc.Declaration declaration) {
      if (declaration != null) {
        workspace.File targetFile = declaration.getFile(file.project);

        // Open targetFile and select the range of text.
        if (targetFile != null) {
          Span selection = new Span(declaration.offset, declaration.length);
          aceManager.delegate.openEditor(targetFile, selection: selection);
        }
      }
    });
  }
}

class CssEditor extends TextEditor {
  static bool isCssFile(workspace.File file) => file.name.endsWith('.css');

  CssEditor._create(AceManager aceManager, workspace.File file) :
      super._create(aceManager, file);

  bool get supportsFormat => true;

  void format() {
    String oldValue = _session.value;
    String newValue = new CssBeautify().format(oldValue);
    if (newValue != oldValue) {
      _replaceContents(newValue);
      dirty = true;
    }
  }
}

/**
 * A wrapper around an Ace editor instance.
 */
class AceManager {
  static final KEY_BINDINGS = ace.KeyboardHandler.BINDINGS;
  /**
   * The container for the Ace editor.
   */
  final html.Element parentElement;
  final AceManagerDelegate delegate;

  Outline outline;

  StreamController _onGotoDeclarationController = new StreamController();
  Stream get onGotoDeclaration => _onGotoDeclarationController.stream;
  GotoLineView gotoLineView;

  ace.Editor _aceEditor;

  workspace.Marker _currentMarker;

  StreamSubscription<ace.FoldChangeEvent> _foldListenerSubscription;

  static bool get available => js.context['ace'] != null;

  StreamSubscription _markerSubscription;
  workspace.File currentFile;
  svc.AnalyzerService _analysisService;

  AceManager(this.parentElement,
             this.delegate,
             svc.Services services,
             PreferenceStore prefs) {
    ace.implementation = ACE_PROXY_IMPLEMENTATION;
    _aceEditor = ace.edit(parentElement);
    _aceEditor.renderer.fixedWidthGutter = true;
    _aceEditor.highlightActiveLine = false;
    _aceEditor.printMarginColumn = 80;
    _aceEditor.readOnly = true;
    _aceEditor.fadeFoldWidgets = true;

    _analysisService =  services.getService("analyzer");

    // Enable code completion.
    ace.require('ace/ext/language_tools');
    _aceEditor.setOption('enableBasicAutocompletion', true);
    _aceEditor.setOption('enableSnippets', true);
    _aceEditor.setOption('enableMultiselect', false);

    // Override Ace's `gotoline` command.
    var command = new ace.Command(
        'gotoline',
        const ace.BindKey(mac: 'Command-L', win: 'Ctrl-L'),
        _showGotoLineView);
    _aceEditor.commands.addCommand(command);

    // Add some additional file extension editors.
    ace.Mode.extensionMap['classpath'] = ace.Mode.XML;
    ace.Mode.extensionMap['cmd'] = ace.Mode.BATCHFILE;
    ace.Mode.extensionMap['diff'] = ace.Mode.DIFF;
    ace.Mode.extensionMap['lock'] = ace.Mode.YAML;
    ace.Mode.extensionMap['project'] = ace.Mode.XML;

    _setupOutline(prefs);
    var node = parentElement.getElementsByClassName("ace_content")[0];
    node.onClick.listen((e) {
      bool accelKey = PlatformInfo.isMac ? e.metaKey : e.ctrlKey;
      if (accelKey) _onGotoDeclarationController.add(null);
    });
  }

  void _setupOutline(PreferenceStore prefs) {
    outline = new Outline(_analysisService, parentElement, prefs);
    outline.onChildSelected.listen((OutlineItem item) {
      ace.Point startPoint =
          currentSession.document.indexToPosition(item.nameStartOffset);
      ace.Point endPoint =
          currentSession.document.indexToPosition(item.nameEndOffset);

      ace.Selection selection = _aceEditor.selection;
      _aceEditor.gotoLine(startPoint.row);
      selection.setSelectionAnchor(startPoint.row, startPoint.column);
      selection.selectTo(endPoint.row, endPoint.column);
      _aceEditor.focus();
    });

    ace.Point lastCursorPosition =  new ace.Point(-1, -1);
    _aceEditor.onChangeSelection.listen((_) {
      ace.Point newCursorPosition = _aceEditor.cursorPosition;
      // Cancel the last outline selection update
      if (lastCursorPosition != newCursorPosition) {
        int cursorOffset = currentSession.document.positionToIndex(
            newCursorPosition);
        outline.selectItemAtOffset(cursorOffset);
      }
      lastCursorPosition = newCursorPosition;
    });

    // Set up the goto line dialog.
    gotoLineView = new GotoLineView();
    gotoLineView.style.zIndex = '101';
    parentElement.children.add(gotoLineView);
    gotoLineView.onTriggered.listen(_handleGotoLineViewEvent);
    gotoLineView.onClosed.listen(_handleGotoLineViewClosed);
    parentElement.onKeyDown
        .where((e) => e.keyCode == html.KeyCode.ESC)
        .listen((_) => gotoLineView.hide());
  }

  bool isFileExtensionEditable(String extension) {
    if (extension.startsWith('.')) {
      extension = extension.substring(1);
    }
    return ace.Mode.extensionMap[extension] != null;
  }

  html.Element get _editorElement => parentElement.parent;

  html.Element get _minimapElement {
    List element = parentElement.getElementsByClassName("minimap");
    return element.length == 1 ? element.first : null;
  }

  String _formatAnnotationItemText(String text, [String type]) {
    String labelHtml = "";
    if (type != null) {
      String typeText = type.substring(0, 1).toUpperCase() + type.substring(1);
      labelHtml = "<span class=ace_gutter-tooltip-label-$type>$typeText: </span>";
    }
    return "$labelHtml$text";
  }

  void setMarkers(List<workspace.Marker> markers) {
    List<ace.Annotation> annotations = [];
    int numberLines = currentSession.screenLength;

    _recreateMiniMap();
    Map<int, ace.Annotation> annotationByRow = new Map<int, ace.Annotation>();

    html.Element minimap = _minimapElement;

    markers.sort((x, y) => x.lineNum.compareTo(y.lineNum));
    int numberMarkers = markers.length.clamp(0, 100);

    var isScrolling = (_aceEditor.lastVisibleRow -
        _aceEditor.firstVisibleRow + 1) < currentSession.document.length;

    int documentHeight;
    if (!isScrolling) {
      var lineElements = parentElement.getElementsByClassName("ace_line");
      documentHeight = (lineElements.last.offsetTo(parentElement).y -
          lineElements.first.offsetTo(parentElement).y);
    }

    for (int markerIndex = 0; markerIndex < numberMarkers; markerIndex++) {
      workspace.Marker marker = markers[markerIndex];
      String annotationType = _convertMarkerSeverity(marker.severity);

      // Style the marker with the annotation type.
      String markerHtml = _formatAnnotationItemText(marker.message,
          annotationType);

      // Ace uses 0-based lines.
      ace.Point charPoint = currentSession.document.indexToPosition(
          marker.charStart);
      int aceRow = charPoint.row;
      int aceColumn = charPoint.column;

      // If there is an existing annotation, delete it and combine into one.
      var existingAnnotation = annotationByRow[aceRow];
      if (existingAnnotation != null) {
        markerHtml = existingAnnotation.html
            + "<div class=\"ace_gutter-tooltip-divider\"></div>$markerHtml";
        annotations.remove(existingAnnotation);
      }

      ace.Annotation annotation = new ace.Annotation(
          html: markerHtml,
          row: aceRow,
          type: annotationType);
      annotations.add(annotation);
      annotationByRow[aceRow] = annotation;

      double markerHorizontalPercentage = currentSession.documentToScreenRow(
          marker.lineNum, aceColumn) / numberLines;

      String markerPos;
      if (!isScrolling) {
        markerPos = (markerHorizontalPercentage * documentHeight).toString() + "px";
      } else {
        markerPos = (markerHorizontalPercentage * 100.0)
            .toStringAsFixed(2) + "%";
      }

      // TODO(ericarnold): This should also be based upon annotations so ace's
      //     immediate handling of deleting / adding lines gets used.

      // Only add errors and warnings to the mini-map.
      if (marker.severity >= workspace.Marker.SEVERITY_WARNING) {
        html.Element minimapMarker = new html.Element.div();
        minimapMarker.classes.add("minimap-marker ${marker.severityDescription}");
        minimapMarker.style.top = markerPos;
        minimapMarker.onClick.listen((e) => _miniMapMarkerClicked(e, marker));

        minimap.append(minimapMarker);
      }
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

  void _miniMapMarkerClicked(html.MouseEvent event, workspace.Marker marker) {
    event.stopPropagation();
    event.preventDefault();
    _selectMarker(marker);
  }

  void _selectMarker(workspace.Marker marker) {
    _aceEditor.gotoLine(marker.lineNum);
    ace.Selection selection = _aceEditor.selection;
    ace.Range range = selection.getLineRange(marker.lineNum - 1);
    selection.setSelectionAnchor(range.end.row, range.end.column);
    selection.selectTo(range.start.row, range.start.column);
    _aceEditor.focus();
    _currentMarker = marker;
  }

  void _recreateMiniMap() {
    if (parentElement == null) {
      return;
    }

    html.Element miniMap = new html.Element.div();
    miniMap.classes.add("minimap");

    if (_minimapElement != null) {
      _minimapElement.replaceWith(miniMap);
    } else {
      parentElement.append(miniMap);
    }
  }

  /**
   * Show an overlay dialog to tell the user that a binary file cannot be
   * shown.
   *
   * TODO(dvh): move this logic to editors/editor_area.
   * See https://github.com/dart-lang/spark/issues/906
   */
  void createDialog(String filename) {
    if (_editorElement == null) {
      return;
    }
    html.Element dialog = _editorElement.querySelector('.editor-dialog');
    if (dialog != null) {
      // Dialog already exists.
      return;
    }

    dialog = new html.Element.div();
    dialog.classes.add("editor-dialog");

    // Add an overlay dialog using the template #editor-dialog.
    html.DocumentFragment template =
        (html.querySelector('#editor-dialog') as html.TemplateElement).content;
    html.DocumentFragment templateClone = template.clone(true);
    html.Element element = templateClone.querySelector('.editor-dialog');
    element.classes.remove('editor-dialog');
    dialog.append(element);

    // Set actions of the dialog.
    html.ButtonElement button = dialog.querySelector('.view-as-text-button');
    button.onClick.listen((_) {
      dialog.classes.add("transition-hidden");
      focus();
    });
    html.Element link = dialog.querySelector('.always-view-as-text-button');
    link.onClick.listen((_) {
      dialog.classes.add("transition-hidden");
      delegate.setShowFileAsText(currentFile.name, true);
      focus();
    });

    if (delegate.canShowFileAsText(filename)) {
      dialog.classes.add('hidden');
    }

    _editorElement.append(dialog);
  }

  void clearMarkers() => currentSession.clearAnnotations();

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

  html.Point get cursorPosition {
    ace.Point cursorPosition = _aceEditor.cursorPosition;
    return new html.Point(cursorPosition.column, cursorPosition.row);
  }

  void set cursorPosition(html.Point position) {
    _aceEditor.navigateTo(position.y, position.x);
  }

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

  ace.EditSession get currentSession => _aceEditor.session;

  void switchTo(ace.EditSession session, [workspace.File file]) {
    if (_foldListenerSubscription != null) {
      _foldListenerSubscription.cancel();
      _foldListenerSubscription = null;
    }

    if (session == null) {
      _aceEditor.session = ace.createEditSession('', new ace.Mode('ace/mode/text'));
    } else {
      _aceEditor.session = session;

      _foldListenerSubscription = currentSession.onChangeFold.listen((_) {
        setMarkers(file.getMarkers());
      });
    }

    // Setup the code completion options for the current file type.
    if (file != null) {
      currentFile = file;
      // For now, we turn on lexical code completion for Dart files. We'll want
      // to switch this over to semantic code completion soonest.
      //_aceEditor.setOption(
      //    'enableBasicAutocompletion', path.extension(file.name) != '.dart');

      if (_markerSubscription == null) {
        _markerSubscription = file.workspace.onMarkerChange.listen(
            _handleMarkerChange);
      }

      setMarkers(file.getMarkers());
      buildOutline();
    }
  }

  /**
   * Make a service call and build the outline view for the current file.
   */
  void buildOutline() {
    String name = currentFile == null ? '' : currentFile.name;

    if (!name.endsWith(".dart")) return;

    String text = currentSession.value;
    outline.build(name, text);
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
      default:
        return ace.Annotation.INFO;
    }
  }

  void _showGotoLineView(_) => gotoLineView.show();

  void _handleGotoLineViewEvent(int line) {
    _aceEditor.gotoLine(line);
    gotoLineView.hide();
  }

  void _handleGotoLineViewClosed(_) => focus();
}

class ThemeManager {
  static final LIGHT_THEMES = [
      'textmate', 'tomorrow'
  ];
  static final DARK_THEMES = [
      'monokai', 'tomorrow_night', 'idle_fingers', 'pastel_on_dark'
  ];

  ace.Editor _aceEditor;
  PreferenceStore _prefs;
  html.Element _label;
  List<String> _themes = [];

  ThemeManager(AceManager aceManager, this._prefs, this._label) :
      _aceEditor = aceManager._aceEditor {
    if (SparkFlags.useAceThemes) {
      if (SparkFlags.useDarkAceThemes) _themes.addAll(DARK_THEMES);
      if (SparkFlags.useLightAceThemes) _themes.addAll(LIGHT_THEMES);

      _prefs.getValue('aceTheme').then((String theme) {
        if (theme == null || theme.isEmpty || !_themes.contains(theme)) {
          theme = _themes[0];
        }
        _updateTheme(theme);
      });
    } else {
      _themes.add(DARK_THEMES[0]);
      _updateTheme(_themes[0]);
    }
  }

  void nextTheme(html.Event e) {
    e.stopPropagation();
    _changeTheme(1);
  }

  void prevTheme(html.Event e) {
    e.stopPropagation();
    _changeTheme(-1);
  }

  void _changeTheme(int direction) {
    int index = _themes.indexOf(_aceEditor.theme.name);
    index = (index + direction) % _themes.length;
    String newTheme = _themes[index];
    _updateTheme(newTheme);
  }

  void _updateTheme(String theme) {
    if (SparkFlags.useAceThemes) {
      _prefs.setValue('aceTheme', theme);
    }
    _aceEditor.theme = new ace.Theme.named(theme);
    if (_label != null) {
      _label.text = utils.toTitleCase(theme.replaceAll('_', ' '));
    }
  }
}

class KeyBindingManager {
  AceManager aceManager;
  PreferenceStore prefs;
  html.Element _label;

  KeyBindingManager(this.aceManager, this.prefs, this._label) {
    prefs.getValue('keyBindings').then((String value) {
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
      prefs.setValue('keyBindings', newBinding);
      _updateName(newBinding);
      aceManager.setKeyBinding(newBinding);
    });
  }

  void _updateName(String name) {
    _label.text = (name == null ? 'Default' : utils.capitalize(name));
  }
}

abstract class AceManagerDelegate {
  /**
   * Mark the files with the given file extension as editable in text format.
   */
  void setShowFileAsText(String extension, bool enabled);

  /**
   * Returns true if the file with the given filename can be edited as text.
   */
  bool canShowFileAsText(String filename);

  void openEditor(workspace.File file, {Span selection});
}

String _calcMD5(String text) {
  crypto.MD5 md5 = new crypto.MD5();
  md5.add(text.codeUnits);
  return crypto.CryptoUtils.bytesToHex(md5.close());
}
