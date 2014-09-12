// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.services_bootstrap;

/**
 * Uncomment one of the 2 exports below to switch between the isolate and
 * single thread implementations of worker services.
 */

export 'services_bootstrap_isolate.dart';
//export 'services_bootstrap_single_thread.dart';
