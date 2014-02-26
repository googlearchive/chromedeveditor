// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.uuid;

int _next_id = 0;

/**
 * A temporary version of the Uuid class from package:uuid. The current version
 * specifies older versions of the `unittest` and `cipher` library then we want
 * to use.
 */
class Uuid {
  String v4() => '_uuid_${_next_id++}';
}
