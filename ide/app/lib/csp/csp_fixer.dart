// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * CSP compatibility postprocessor.
 */

library spark.csp.fixer;

import 'dart:async';
//import 'dart:html';

import 'package:logging/logging.dart';
import 'package:html5lib/parser.dart' as html_parser;
import 'package:html5lib/dom.dart' as dom;

import '../workspace.dart' as ws;

final Logger _logger = new Logger('spark.csp_fixer');

class CspFixer {
  static final _HTML_FNAME_RE = new RegExp(r'^(.+)\.(htm|html|HTM|HTML)$');

  final ws.Folder _rootDir;
  final bool _includeDerived;

  CspFixer(this._rootDir, {includeDerived: true}) :
      _includeDerived = includeDerived;

  Future process() {
    _rootDir.traverse(includeDerived: _includeDerived)
        .where((ws.Resource r) => r is ws.File)
        .forEach((ws.Resource r) => _processFile(r as ws.File));
    return new Future.value();
  }

  Future _processFile(ws.File file) {
    final Match m = _HTML_FNAME_RE.matchAsPrefix(file.path);
    if (m == null) return new Future.value();

    final String htmlBasePath = m.group(1);
    final String htmlExt = m.group(2);

    return file.getContents().then((final String htmlText) {
      _logger.info("processing ${file.path}...");

      dom.Document doc;
      try {
        doc = html_parser.parse(htmlText);
      } catch (e) {
        _logger.warning("parsing failed for ${file.path}: $e");
        return new Future.error(e);
      }

      Map<String, String> newFiles = {};
      int scriptIdx = 1;

      doc.querySelectorAll('script').forEach((script) {
        if (script.innerHtml.isNotEmpty) {
          final String scriptName = '${file.name}.$scriptIdx.js';
          final String scriptPath = '$htmlBasePath.$scriptIdx.js';
          ++scriptIdx;
          newFiles[scriptPath] = script.innerHtml;
          script.attributes['src'] = scriptName;
          script.innerHtml = '';
        }
      });

      if (newFiles.isNotEmpty) {
        newFiles[file.path + '.orig'] = htmlText;
        newFiles[file.path] = doc.outerHtml;
      }

      List<Future> writeFutures = [];
      newFiles.forEach((final fPath, final fText) {
        writeFutures.add(_writeFile(fPath, fText));
      });

      return Future.wait(writeFutures);
    });
  }

  Future _writeFile(String filePath, String fileText) {
    return _rootDir.getOrCreateFile(filePath, true).then(
        (ws.File file) => file.setContents(fileText));
  }
}
