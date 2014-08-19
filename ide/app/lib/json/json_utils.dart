// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.json.utils;

/**
 * Representation of a (Line, Column) pair, both 1-based.
 */
class LineColumn {
  final int line;
  final int column;
  LineColumn(this.line, this.column) {
    assert(line >= 1);
    assert(column >= 1);
  }
}

/**
 * Utility class for converting between offsets and [LineColumn] positions for
 * a string containing newline characters (e.g. the contents of a text file).
 */
class StringLineOffsets {
  final String _contents;
  List<int> _lineOffsets;

  StringLineOffsets(this._contents);

  /**
   * Returns a 1-based [LineColumn] instances from an offset [position].
   */
  LineColumn getLineColumn(int position) {
    int lineIndex = _calcLineIndex(position);
    int columnIndex = position - _lineOffsets[lineIndex];
    return new LineColumn(lineIndex + 1, columnIndex + 1);
  }

  /**
   * Counts the newlines between 0 and position.
   */
  int _calcLineIndex(int position) {
    assert(position >= 0);
    if (_lineOffsets == null) {
      _lineOffsets = _createLineOffsets(_contents);
    }

    int lineIndex = _binarySearch(_lineOffsets, position);
    if (lineIndex < 0) {
      // Note: we need "- 2" because 1) we adjust for the "+1" of the return
      // value of the search (insertion position), and 2) we are interested
      // in the line containing [position], not the insertion position of
      // [position] in the array.
      lineIndex = -lineIndex - 2;
    }
    assert(lineIndex >= 0 && lineIndex < _lineOffsets.length);
    return lineIndex;
  }

  /**
   * Returns the position of [item] in [items] if present.
   * Returns "-(insertion_position + 1)" if [item] is not found.
   */
  static int _binarySearch(List items, var item) {
   int min = 0;
   int max = items.length - 1;
   while (min <= max) {
     int med = (min + max) ~/ 2;
     if (items[med] < item) {
       min = med + 1;
     } else if (items[med] > item) {
       max = med - 1;
     } else {
       return med;
     }
   }
   // [min] is the insertion position in the range [0, max].
   // Return a negative value in the range [-max - 1, -1].
   return -(min + 1);
  }

  /**
   * Creates a sorted array of positions where line starts in [source].
   * The first element of the returned array is always 0.
   * TODO(rpaquay): This should be part of [File] maybe?
   */
  static List<int> _createLineOffsets(String source) {
   List<int> result = new List<int>();
   result.add(0);  // first line always starts at offset 0
   for (int index = 0; index < source.length; index++) {
     // TODO(rpaquay): Are there other characters to consider as "end of line".
     if (source[index] == '\n') {
       result.add(index + 1);
     }
   }
   return result;
  }
}
