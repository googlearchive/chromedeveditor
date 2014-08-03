// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// TODO(ussuri): See what other CSP violations could be fixed here.

library spark.csp.fixer;

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:html5lib/parser.dart' as html_parser;
import 'package:html5lib/dom.dart' as dom;

import '../workspace.dart' as ws;

final Logger _logger = new Logger('spark.csp_fixer');

/**
 * CSP compatibility postprocessor.
 *
 * Recursively traverses a given folder and outlines all inlined <script> tags
 * in all found HTML files. This makes such files CSP-compatible with respect
 * to inlined scripts.
 */
class CspFixer {
  static final _HTML_FNAME_RE = new RegExp(r'^(.+)\.(htm|html|HTM|HTML)$');

  final ws.Folder _rootDir;
  final bool _includeDerived;

  CspFixer(this._rootDir, {includeDerived: true}) :
      _includeDerived = includeDerived;

  Future process() {
    final Iterable<Future> futures = _rootDir
        .traverse(includeDerived: _includeDerived)
        .where((ws.Resource r) => r is ws.File)
        .map((ws.File r) => _processFile(r));
    return Future.wait(futures);
  }

  Future _processFile(ws.File file) {
    final Match m = _HTML_FNAME_RE.matchAsPrefix(file.path);
    if (m == null) return new Future.value();

    final String htmlBasePath = m.group(1);
    final String htmlExt = m.group(2);

    return file.getContents().then((final String htmlText) {
      _logger.info("processing ${file.path} for CSP...");

      dom.Document doc;
      try {
        doc = html_parser.parse(htmlText);
      } catch (e) {
        _logger.warning("Parsing failed for ${file.path}: $e");
        return new Future.error(e);
      }

      List<_FileWriter> newFiles = [];
      int scriptIdx = 1;

      // For every inline <script> tag in the HTML:
      // 1) output the script into a new file;
      // 2) remove the original <script>'s body from the HTML;
      // 3) point the resulting empty <script>'s src at the outlined file.
      doc.querySelectorAll('script').forEach((script) {
        if (script.innerHtml.isNotEmpty) {
          final String scriptName = '${file.name}.$scriptIdx.js';
          ++scriptIdx;
          newFiles.add(
              new _FileWriter(file.parent, scriptName, script.innerHtml));
          script.attributes['src'] = scriptName;
          script.innerHtml = '';
        }
      });

      // If there are any files to write, the original HTML has been altered.
      if (newFiles.isNotEmpty) {
        // Back up the original HTML.
        newFiles.add(
            new _FileWriter(file.parent, file.name + '.orig', htmlText));
        // Write the processed HTML over the original.
        newFiles.add(
            new _FileWriter(file.parent, file.name, doc.outerHtml));
      }

      // Write files sequentially.
      return Future.forEach(newFiles, (_FileWriter writer) => writer.write());
    });
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
