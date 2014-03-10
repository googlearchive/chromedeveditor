// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This class is the list of callbacks methods needed for
 * `FilesControllerDelegate`.
 */
library spark.ui.widgets.files_controller_delegate;

import 'dart:html' as html;

import '../actions.dart';
import '../workspace.dart';

abstract class FilesControllerDelegate {
  /**
   * The implementation of this method should open the given file in an editor.
   */
  void selectInEditor(File file,
                      {bool forceOpen: false, bool replaceCurrent: true});

  /**
   * This should return the top HTML element representing the (hidden)
   * context menu (which should have class 'dropdown-menu') and its backdrop
   * (which should have class '.backdrop').
   */
  html.Element getContextMenuContainer();

  /**
   * Returns the list of actions that apply in the context of the given
   * [resource].
   */
  List<ContextAction> getActionsFor(List<Resource> resources);
  
  /**
   * The implementation of this method should report an error.
   */
   void showErrorMessage(String title, String message);
}
