// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'commands_test.dart' as app_commands_test;
import 'context_test.dart' as context_test;
import 'keys_test.dart' as keys_test;

void main() {
  app_commands_test.defineTests();
  context_test.defineTests();
  keys_test.defineTests();
}
