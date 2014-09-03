// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * An abstraction for a context or location in an application. See [Context].
 */
library cde_workbench.context;

import 'package:cde_core/adaptable.dart';

/**
 * A context in an application. A [Context] can be adapted to different types,
 * so the client of the context can try and convert it into something that it
 * knows how to act on.
 */
abstract class Context implements Adaptable {
  dynamic adapt(Type type);
}
