// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This class is the list of callbacks methods needed for
 * `FilesControllerDelegate`.
 */
library spark.ui.widgets.files_controller_delegate;

import '../workspace.dart';

abstract class FilesControllerDelegate {
  /**
   * The implementation of this method should open the given file in an
   * editor.
   */
  void openInEditor(File file);
}
