// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// TODO(ussuri): See what other CSP violations could be fixed here.

library spark.csp.fixer;

import 'dart:async';

import 'package:html5lib/dom.dart' as dom;
import 'package:html5lib/parser.dart' as html_parser;
import 'package:logging/logging.dart';
import 'package:quiver/async.dart' as quiver;

import '../jobs.dart';
import '../spark_flags.dart';
import '../workspace.dart' as ws;

final Logger _logger = new Logger('spark.csp_fixer');
final _HTML_FNAME_RE = new RegExp(r'^.+\.(htm|html|HTM|HTML)$');

/**
 * CSP compatibility postprocessor.
 *
 * Recursively traverses a given folder and fixes some of the known CSP
 * violations. In particular, outlines all inlined <script> tags
 * in all HTML files under a given list of files/folders. That makes such
 * files CSP-compliant with respect to inlined scripts.
 */
class CspFixer {
  final ws.Resource _resource;
  final ProgressMonitor _monitor;

  /**
   * Returns true if at least one of the given resources is or contains
   * some candidates for CSP fixing. A candidate is currently loosely defined
   * as either an HTML file, or the Pub/Bower packages folder or its subfilder.
   */
  static bool mightProcess(List resources) {
    // TODO(ussuri): Expand onto
    return resources.any((r) {
      return (r is ws.File && _HTML_FNAME_RE.hasMatch(r.name)) ||
             (r is ws.Container && mightProcess(r.getChildren()));
    });
  }

  CspFixer(this._resource, this._monitor);

  Future<SparkJobStatus> process() {
    _monitor.start(
        "Refactoring for CSP…",
        maxWork: 0,
        format: ProgressFormat.N_OUT_OF_M);

    Iterable<ws.File> files;
    if (_resource is ws.File) {
      files = [_resource];
    } else if (_resource is ws.Container) {
      // NOTE: [traverse] will auto-skip special SCM folders such as `.git`.
      files = _resource
          .traverse(includeDerived: true)
          .where((ws.Resource r) => r is ws.File);
    }

    final List<_CspFixerSingleFile> fixers = files
        .where((ws.File f) => _CspFixerSingleFile.willProcess(f))
        .map((ws.File f) => new _CspFixerSingleFile(f))
        .toList();

    _monitor.addWork(fixers.length);

    // Process input files in parallel to maximize I/O and make failures
    // independent, but throttle the maximum concurrent thread in order
    // not to freeze the UI too much.
    // TODO(ussuri): Use ServiceWorker here to completely unfreeze the UI.
    return quiver.forEachAsync(fixers, (fixer) {
      return fixer.process().whenComplete(() => _monitor.worked(1));
    }, maxTasks: SparkFlags.cspFixerMaxConcurrentTasks).then((_) {
      _monitor.done();
      return new SparkJobStatus(code: SparkStatusCodes.SPARK_JOB_BUILD_SUCCESS);
    });
  }
}

class _CspFixerSingleFile {
  final ws.File _file;
  dom.Document _document;
  List<_FileWriter> _newFiles = [];

  static bool willProcess(ws.File file) =>
      _HTML_FNAME_RE.matchAsPrefix(file.path) != null;

  _CspFixerSingleFile(this._file);

  Future process() {
    if (!willProcess(_file)) return new Future.value();

    return _file.getContents().then((final String htmlText) {
      try {
        _document = html_parser.parse(htmlText);
      } catch (e) {
        _logger.warning("Parsing failed for ${_file.path}: $e");
        return new Future.error(e);
      }

      _outlineScripts();
      _outlineEventHandlers();
      // TODO(ussuri): Fix other known and fixable CSP violations.

      // If there are any files to write, the original HTML has been altered:
      // 1) back up the original HTML file;
      // 2) replace it with the postprocessed HTML text.
      if (_newFiles.isNotEmpty) {
        if (SparkFlags.cspFixerBackupOriginalSources) {
          _newFiles.add(
              new _FileWriter(_file.parent, _file.name + '.pre_csp', htmlText));
        }
        // NOTE: doc.outerHtml may insert originally omitted parts of a standard
        // HTML document spec. One important example is Polymer elements, which
        // normally don't have <head> or <body>, but will after postprocessing.
        // That doesn't affect their functionality, though, so it's ok.
        _newFiles.add(
            new _FileWriter(_file.parent, _file.name, _document.outerHtml));
      }

      // Write files sequentially: file processing is already parallelized at
      // a higher level, plus parallelizing I/O doesn't do much.
      return Future.forEach(_newFiles, (_FileWriter writer) => writer.write());
    });
  }

  void _outlineScripts() {
    // Outline all inline <script> tags in the HTML:
    // 1) output each script into a new file;
    // 2) remove the original <script>'s body from the HTML;
    // 3) point the resulting empty <script>'s [src] at the outlined file.
    int scriptIdx = 0;
    _document.querySelectorAll('script').forEach((dom.Element script) {
      if (script.innerHtml.isNotEmpty) {
        final String scriptExt = _getScriptExtension(script);
        final String scriptName = '${_file.name}.${scriptIdx}.${scriptExt}';
        ++scriptIdx;

        _newFiles.add(
            new _FileWriter(_file.parent, scriptName, script.innerHtml));
        script.attributes['src'] = scriptName;
        script.innerHtml = '';
      }
    });
  }

  void _outlineEventHandlers() {
    // TODO(ussuri): Implement.
  }

  static const _TYPE_TO_EXT = const {
    null: 'js',
    'application/javascript': 'js',
    'application/dart': 'dart',
    'text/coffeescript': 'coffee'
  };

  String _getScriptExtension(dom.Element script) {
    final String type = script.attributes['type'];
    final String ext = _TYPE_TO_EXT[type];
    // NOTE: The attempt to deduce the extension for an unknown type is only
    // half-decent.
    return ext != null ? ext : type.replaceAll('application/', '');
  }
}

class _FileWriter {
  final ws.Folder destDir;
  final String fileName;
  final String fileText;

  _FileWriter(this.destDir, this.fileName, this.fileText);

  Future write() {
    return destDir.getOrCreateFile(fileName, true).then(
        (ws.File file) => file.setContents(fileText));
  }
}
