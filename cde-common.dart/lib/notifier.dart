// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * TODO:
 */
library cde_common.notifier;

import 'dart:async';

abstract class Notifier {
  void showDialog(String title, String message);

  void displaySuccess(String message);

  void displayError(String message);

  Future<bool> askUserOkCancel(String title, String message,
      {String okButtonLabel, String cancelButtonLabel});
}
