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
import 'markdown.dart';
import 'navigation.dart';
import 'package_mgmt/bower_properties.dart';
import 'package_mgmt/pub_properties.dart';
import 'platform_info.dart';
import 'preferences.dart';
import 'utils.dart' as utils;
import 'workspace.dart' as workspace;
import 'services.dart' as svc;
import 'outline.dart';
import 'ui/polymer/goto_line_view/goto_line_view.dart';
import 'utils.dart';

export 'package:ace/ace.dart' show EditSession;

class TextEditor extends Editor {
  static final RegExp whitespaceRegEx = new RegExp('[\t ]*\$', multiLine:true);

  final AceManager aceManager;
  final workspace.File file;

  StreamSubscription _aceSubscription;
  StreamController _dirtyController = new StreamController.broadcast();
  StreamController _modificationController = new StreamController.broadcast();
  Completer<Editor> _whenReadyCompleter = new Completer();

  final SparkPreferences _prefs;
  ace.EditSession _session;

  String _lastSavedHash;

  bool _dirty = false;

  factory TextEditor(AceManager aceManager, workspace.File file,
      SparkPreferences prefs) {
    if (DartEditor.isDartFile(file)) {
      return new DartEditor._create(aceManager, file, prefs);
    }
    if (CssEditor.isCssFile(file)) {
      return new CssEditor._create(aceManager, file, prefs);
    }
    if (MarkdownEditor.isMarkdownFile(file)) {
      return new MarkdownEditor._create(aceManager, file, prefs);
    }
    return new TextEditor._create(aceManager, file, prefs);
  }

  TextEditor._create(this.aceManager, this.file, this._prefs);

  Future<Editor> get whenReady => _whenReadyCompleter.future;

  void setSession(ace.EditSession value) {
    _session = value;
    if (_aceSubscription != null) _aceSubscription.cancel();
    _aceSubscription = _session.onChange.listen((_) => dirty = true);
    if (!_whenReadyCompleter.isCompleted) _whenReadyCompleter.complete(this);

    _invokeReconcile();
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

  /**
   * Called a short delay after the file's content has been altered.
   */
  void reconcile() { }

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

  Future navigateToDeclaration([Duration timeLimit]) => new Future.value();

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

  Future save() {
    // We store a hash of the contents when saving. When we get a change
    // notification (in fileContentsChanged()), we compare the last write to the
    // contents on disk.
    if (_dirty) {
      String text = _session.value;

      // Remove the trailing whitespace if asked to do so.
      if (_prefs.stripWhitespaceOnSave) {
        text = text.replaceAll(whitespaceRegEx, '');
      }

      _lastSavedHash = _calcMD5(text);

      return file.setContents(text).then((_) {
        dirty = false;
        _invokeReconcile();
      });
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

      _invokeReconcile();
    } finally {
      _aceSubscription = _session.onChange.listen((_) => dirty = true);
    }
  }

  void _invokeReconcile() {
    reconcile();
  }
}

class DartEditor extends TextEditor {
  static bool isDartFile(workspace.File file) => file.name.endsWith('.dart');

  int outlineScrollPosition = 0;

  DartEditor._create(AceManager aceManager, workspace.File file,
      SparkPreferences prefs) : super._create(aceManager, file, prefs);

  bool get supportsOutline => true;

  @override
  void activate() {
    super.activate();

    if (_session != null) {
      _outline.build(file.name, _session.value);
    }

    _outline.scrollPosition = outlineScrollPosition;
  }

  @override
  void deactivate() {
    super.deactivate();

    outlineScrollPosition = _outline.scrollPosition;
  }

  void reconcile() {
    int pos = _outline.scrollPosition;
    _outline.build(file.name, _session.value).then((_) {
      _outline.scrollPosition = pos;
    });
  }

  Outline get _outline => aceManager.outline;

  Future<svc.Declaration> navigateToDeclaration([Duration timeLimit]) {
    int offset = _session.document.positionToIndex(
        aceManager._aceEditor.cursorPosition);

    Future declarationFuture = aceManager._analysisService.getDeclarationFor(
        file, offset);

    if (timeLimit != null) {
      declarationFuture = declarationFuture.timeout(timeLimit, onTimeout: () =>
          throw new TimeoutException("navigateToDeclaration timed out"));
    }

    return declarationFuture.then((svc.Declaration declaration) {
      if (declaration != null) {
        if (declaration is svc.SourceDeclaration) {
          workspace.File targetFile = declaration.getFile(file.project);

          // Open targetFile and select the range of text.
          if (targetFile != null) {
            Span selection = new Span(declaration.offset, declaration.length);
            aceManager.delegate.openEditor(targetFile, selection: selection);
          }
        } else if (declaration is svc.DocDeclaration) {
          html.window.open(declaration.url, "spark_doc");
        }
      }
      return declaration;
    });
  }
}

class CssEditor extends TextEditor {
  static bool isCssFile(workspace.File file) => file.name.endsWith('.css');

  CssEditor._create(AceManager aceManager, workspace.File file,
    SparkPreferences prefs) : super._create(aceManager, file, prefs);

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

class MarkdownEditor extends TextEditor {
  static bool isMarkdownFile(workspace.File file) =>
      file.name.toLowerCase().endsWith('.md');

  Markdown _markdown;

  MarkdownEditor._create(AceManager aceManager, workspace.File file,
    SparkPreferences prefs) : super._create(aceManager, file, prefs) {
       _markdown = new Markdown(element, file);
  }

  @override
  void activate() {
    super.activate();
    _markdown.activate();
  }

  @override
  void deactivate() {
    super.deactivate();
    _markdown.deactivate();
  }

  @override
  void reconcile() {
    _markdown.renderHtml();
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
  final html.Element _parentElement;
  html.Element get parentElement =>
      _parentElement;
  final AceManagerDelegate delegate;
  final PreferenceStore _prefs;

  Outline outline;

  StreamController _onGotoDeclarationController = new StreamController();
  Stream get onGotoDeclaration => _onGotoDeclarationController.stream;
  GotoLineView gotoLineView;

  ace.Editor _aceEditor;
  ace.EditSession _currentSession;

  workspace.Marker _currentMarker;

  StreamSubscription<ace.FoldChangeEvent> _foldListenerSubscription;

  static bool get available => js.context['ace'] != null;

  StreamSubscription _markerSubscription;
  workspace.File currentFile;
  svc.AnalyzerService _analysisService;
  

  AceManager(this._parentElement,
             this.delegate,
             svc.Services services,
             this._prefs) {
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

    if (PlatformInfo.isMac) {
      command = new ace.Command(
          'scrolltobeginningofdocument',
          const ace.BindKey(mac: 'Home'),
          _scrollToBeginningOfDocument);
      _aceEditor.commands.addCommand(command);

      command = new ace.Command(
          'scrolltoendofdocument',
          const ace.BindKey(mac: 'End'),
          _scrollToEndOfDocument);
      _aceEditor.commands.addCommand(command);
    }

    // Remove the `ctrl-,` binding.
    _aceEditor.commands.removeCommand('showSettingsMenu');

    // Add some additional file extension editors.
    ace.Mode.extensionMap['classpath'] = ace.Mode.XML;
    ace.Mode.extensionMap['cmd'] = ace.Mode.BATCHFILE;
    ace.Mode.extensionMap['diff'] = ace.Mode.DIFF;
    ace.Mode.extensionMap['lock'] = ace.Mode.YAML;
    ace.Mode.extensionMap['nmf'] = ace.Mode.JSON;
    ace.Mode.extensionMap['project'] = ace.Mode.XML;

    _setupGotoLine();

    var node = parentElement.getElementsByClassName("ace_content")[0];
    node.onClick.listen((e) {
      bool accelKey = PlatformInfo.isMac ? e.metaKey : e.ctrlKey;
      if (accelKey) _onGotoDeclarationController.add(null);
    });
  }

  void setupOutline() {
    outline = new Outline(_analysisService, parentElement.parent, _prefs);

    outline.onChildSelected.listen((OutlineItem item) {
      Stopwatch timer = new Stopwatch()..start();
      ace.Point startPoint =
          currentSession.document.indexToPosition(item.nameStartOffset);
      ace.Point endPoint =
          currentSession.document.indexToPosition(item.nameEndOffset);

      ace.Selection selection = _aceEditor.selection;
      _aceEditor.gotoLine(startPoint.row);
      selection.setSelectionAnchor(startPoint.row, startPoint.column);
      selection.selectTo(endPoint.row, endPoint.column);
      _aceEditor.focus();
      print('selection finished in ${timer.elapsedMilliseconds}ms');
    });

    ace.Point lastCursorPosition =  new ace.Point(-1, -1);
    _aceEditor.onChangeSelection.listen((_) {
      return;
      ace.Point currentPosition = _aceEditor.cursorPosition;
      // Cancel the last outline selection update.
      if (lastCursorPosition != currentPosition) {
        outline.selectItemAtOffset(
            currentSession.document.positionToIndex(currentPosition));
        lastCursorPosition = currentPosition;
      }
    });
  }

  // Set up the goto line dialog.
  void _setupGotoLine() {
    gotoLineView = new GotoLineView();
    if (gotoLineView is! GotoLineView) {
      html.querySelector('#splashScreen').style.backgroundColor = 'red';
    }
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
    if (type == null) return text;

    return "<img class='ace-tooltip' src='images/${type}_icon.png'> ${text}";
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

    num documentHeight;
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

      ace.Point charPoint = currentSession.document.indexToPosition(
          marker.charStart);
      // Ace uses 0-based lines.
      int aceRow = marker.lineNum - 1;
      int aceColumn = charPoint.column;

      // If there is an existing annotation, delete it and combine into one.
      var existingAnnotation = annotationByRow[aceRow];
      if (existingAnnotation != null) {
        markerHtml = '${existingAnnotation.html}'
            '<div class="ace-tooltip-divider"></div>${markerHtml}';
        annotations.remove(existingAnnotation);
      }

      ace.Annotation annotation = new ace.Annotation(
          html: markerHtml,
          row: aceRow,
          type: annotationType);
      annotations.add(annotation);
      annotationByRow[aceRow] = annotation;

      double verticalPercentage = currentSession.documentToScreenRow(
          marker.lineNum, aceColumn) / numberLines;

      String markerPos;

      if (!isScrolling) {
        markerPos = '${verticalPercentage * documentHeight}px';
      } else {
        markerPos = (verticalPercentage * 100.0).toStringAsFixed(2) + "%";
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

  num getFontSize() => _aceEditor.fontSize;

  void setFontSize(num size) {
    _aceEditor.fontSize = size;
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

  ace.EditSession get currentSession => _currentSession;

  void switchTo(ace.EditSession session, [workspace.File file]) {
    if (_foldListenerSubscription != null) {
      _foldListenerSubscription.cancel();
      _foldListenerSubscription = null;
    }

    if (session == null) {
      _currentSession = ace.createEditSession('', new ace.Mode('ace/mode/text'));
      _aceEditor.session = _currentSession;
    } else {
      _currentSession = session;
      _aceEditor.session = _currentSession;

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
      session.onChangeScrollTop.listen((_) => Timer.run(() {
        if (outline.visible) {
          int firstCursorOffset = currentSession.document.positionToIndex(
              new ace.Point(_aceEditor.firstVisibleRow, 0));
          int lastCursorOffset = currentSession.document.positionToIndex(
              new ace.Point(_aceEditor.lastVisibleRow, 0));

          outline.scrollToOffsets(firstCursorOffset, lastCursorOffset);
        }
      }));
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
      default:
        return ace.Annotation.INFO;
    }
  }

  void _showGotoLineView(_) {
    html.Element searchElement = parentElement.querySelector('.ace_search');
    if (searchElement != null) searchElement.style.display = 'none';
    gotoLineView.show();
  }

  void _handleGotoLineViewEvent(int line) {
    _aceEditor.gotoLine(line);
    gotoLineView.hide();
  }

  void _handleGotoLineViewClosed(_) => focus();

  void _scrollToBeginningOfDocument(_) {
    _currentSession.scrollTop = 0;
  }

  void _scrollToEndOfDocument(_) {
    int lineHeight = html.querySelector('.ace_gutter-cell').clientHeight;
    _currentSession.scrollTop = _currentSession.document.length * lineHeight;
  }

  NavigationLocation get navigationLocation {
    if (currentFile == null) return null;
    ace.Range range = _aceEditor.selection.range;
    int offsetStart = _currentSession.document.positionToIndex(range.start);
    int offsetEnd = _currentSession.document.positionToIndex(range.end);
    Span span = new Span(offsetStart, offsetEnd - offsetStart);
    return new NavigationLocation(currentFile, span);
  }
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

class AceFontManager {
  AceManager aceManager;
  PreferenceStore prefs;
  html.Element _label;
  num _value;

  AceFontManager(this.aceManager, this.prefs, this._label) {
    _value = aceManager.getFontSize();
    _updateLabel(_value);

    prefs.getValue('fontSize').then((String pref) {
      try {
        _value = num.parse(pref);
        aceManager.setFontSize(_value);
        _updateLabel(_value);
      } catch (e) {

      }
    });
  }

  void dec() => _adjustSize(_value - 2);

  void inc() => _adjustSize(_value + 2);

  void _adjustSize(num newValue) {
    // Clamp to between 6pt and 36pt.
    _value = newValue.clamp(6, 36);
    aceManager.setFontSize(_value);
    _updateLabel(_value);
    prefs.setValue('fontSize', _value.toString());
  }

  void _updateLabel(num size) {
    _label.text = '${size}pt';
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
