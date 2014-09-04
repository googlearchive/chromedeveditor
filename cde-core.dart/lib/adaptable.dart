// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This library contains an implementation of the adaptable pattern.
 */
library cde_core.adaptable;

/**
 * An [Adaptable] object can coerce itself into other object types. For
 * instance, an `Context` type might be able to return an associated `Editor`
 * object when asked, or an `Editor` object might be able to return an
 * associated `File` object.
 *
 * The [Adaptable] pattern is good for when you know what kind of object you
 * want to operate on, but you're not sure at call time which object you've
 * been given.
 */
abstract class Adaptable {
  /**
   * Returns an object which is an instance of the given [Type] associated with
   * this object, or `null` if no such object can be found.
   */
  dynamic adapt(Type type);
}
