// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// TODO(devoncarew): Change these to package imports when we're able.

import '../web/test/app_manifest_validator_test.dart' as app_manifest_validator_test;
import '../web/test/json_parser_test.dart' as json_parser_test;
import '../web/test/json_validator_test.dart' as json_validator_test;

void main() {
  app_manifest_validator_test.defineTests();
  json_parser_test.defineTests();
  json_validator_test.defineTests();
}
