// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.constants;

/**
 * This class represents the possible states of the files in the git
 * repository.
 */
class FileStatusType {
  static const String UNTRACKED = "UNTRACKED";
  static const String MODIFIED = "MODIFIED";
  static const String STAGED = "STAGED";
  static const String COMMITTED = "COMMITTED";
}
