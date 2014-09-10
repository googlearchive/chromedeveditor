// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.permissions;

/**
 * Defines Git Permissions.
 */
class Permissions {
  static String DIRECTORY = "40000";
  static String FILE_NON_EXECUTABLE = "100644";
  static String FILE_NON_EXECUTABLE_GROUP_WRITABLE = "100664";
  static String FILE_EXECUTABLE = "100755";
  static String SYMBOLIC_LINK = "120000";
  static String GIT_LINK = "160000";
}
