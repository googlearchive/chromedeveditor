// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.diff3;

import "package:diff/diff.dart" as diff3;

/**
 * Wrapper for the diff3.dart library.
 */
class Diff3 {
  static Diff3Result diff(String our, String base, String their) {
    diff3.Diff3DigResult diff3DigResult = diff3.diff3Dig(our, base, their);
    return new Diff3Result(diff3DigResult.text.join("\n"),
        diff3DigResult.conflict);
  }
}

class Diff3Result {
  String text;
  bool conflict;
  Diff3Result(this.text, this.conflict);
}
