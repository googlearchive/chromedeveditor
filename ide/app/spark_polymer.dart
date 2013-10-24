// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark;

import 'spark.dart';

void main() {
  SparkPolymer spark = new SparkPolymer();
  spark.start();
}

class SparkPolymer extends Spark {
  SparkPolymer(): super() {
  }
}
