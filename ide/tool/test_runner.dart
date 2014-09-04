// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'package:chrome_testing/testing_cli.dart' as testing;

void main([List<String> args = const []]) {
  // Tweak the params to maintain compatibility wth the previous CLI args.
  if (args.length == 1) {
    args = new List.from(args);

    if (args[0] == '--dartium') {
      args.add('--appPath');
      args.add('app');
    } else if (args[0] == '--chrome') {
      args.add('--appPath');
      args.add('build/deploy-out/web');
    }
  }

  testing.performTesting(args);
}
