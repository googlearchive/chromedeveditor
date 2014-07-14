// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A dirt simple dependency manager for Spark.
 *
 * We may want to upgrade this in the future. For now, we're very leery of
 * anything involving mirrors.
 */
library spark.dependency;

/**
 * A very simple dependency manager. This class manages a collection of
 * singletons. You can create separate `Dependency` instances to manage
 * separate sets of collections (for instance, one for testing). Or, you can use
 * the single [dependency] instance defined in this library to set up all
 * the singletons for your application.
 *
 *     Dependencies dependencies = new Dependencies();
 *     dependencies.setInstance(CatManager, catManager);
 *     dependencies.setInstance(DogManager, dogs);
 *
 *     ...
 *
 *     CatManager cats = dependencies[CatManager];
 *     cats.corale();
 */
class Dependencies {
  Map<Type, dynamic> _instances = {};

  /**
   * A singelton instance of a [Dependency].
   */
  static final Dependencies dependency = new Dependencies();

  Dependencies();

  void operator[]=(Type type, dynamic instance) {
    _instances[type] = instance;
  }

  void setInstance(Type type, dynamic instance) {
    _instances[type] = instance;
  }

  dynamic operator[](Type type) => _instances[type];
  dynamic getInstance(Type type) => _instances[type];

  Iterable<Type> get types => _instances.keys;
}
