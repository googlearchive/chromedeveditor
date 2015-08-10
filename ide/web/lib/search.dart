// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.search;

import 'dart:async';

import 'dart:core' hide Resource;
import 'package:spark_widgets/spark_suggest_box/spark_suggest_box.dart';

import 'workspace.dart';

// TODO(yjbanov): Have to do this because SparkModel is not initialized at the
//                time oracle is created. There should be a better way.
typedef Workspace WsGetter();

/**
 *  Callback invoked with the file user selected to open.
 */
typedef void FileOpener(File file);

/**
 *  Provides search [Suggestion]s for the top-level search box.
 *  Currently searches by file name only.
 */
class SearchOracle implements SuggestOracle {
  final WsGetter _wsGetter;
  final FileOpener _fileOpener;
  final int _maxResultsCount;

  SearchOracle(this._wsGetter, this._fileOpener, [this._maxResultsCount]);

  Stream<List<Suggestion>> getSuggestions(String text) {
    if (text == null || text.trim().isEmpty) {
      return new Stream.fromIterable([[]]);
    }
    text = _cleanse(text);
    // TODO(yjbanov): this is the most naive algorithm ever. We need a way to
    // index the sources and run the search incrementally and preferably in a
    // separate isolate, and test on a large project.
    List suggestions = _wsGetter()
        .traverse()
        .where((res) => res is File && _matches(res.name, text))
        .map((res) => _makeSuggestionFromResource(res))
        .toList(growable: false);
    suggestions.sort(_compareSuggestions);
    if (_maxResultsCount != null) {
      suggestions = suggestions.take(_maxResultsCount).toList(growable: false);
    }
    return new Stream.fromIterable([suggestions]);
  }

  static String _cleanse(String s) =>
      s.trim().replaceAll('_', '').replaceAll('-', '').toLowerCase();

  static bool _matches(String string, String searchText) =>
      string != null && _cleanse(string).contains(searchText);

  Suggestion _makeSuggestionFromResource(Resource res) {
    return new Suggestion(
        res.name,
        details: res.parent.path,
        onSelected: () => _fileOpener(res));
  }

  static int _compareSuggestions(Suggestion a, Suggestion b) {
    int res = a.label.toLowerCase().compareTo(b.label.toLowerCase());
    if (res == 0) {
      res = a.details.toLowerCase().compareTo(b.details.toLowerCase());
    }
    return res;
  }
}
