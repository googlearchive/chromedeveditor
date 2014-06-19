// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.ignore;

/**
 * Implements pattern checking on files specified in .gitignore files.
 * TODO(grv): Add parsing of .gitignore files and pattern checking. The
 * objectstore may instantiate it with the paterns in the implementation.
 */
class GitIgnore {

  /// Returns true if the file with given [path] should be ignored by git.
  static bool ignore(String path) {
    // ignore .lock files for now.
    return path.endsWith(('pubspec.lock')) || path.endsWith(('.DS_Store'));
  }
}
