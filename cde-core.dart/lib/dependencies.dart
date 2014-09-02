// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A simple dependency manager for Chrome Dev Editor.
 */
library core.dependencies;

import 'dart:async';

/**
 * A simple dependency manager. This class manages a collection of singletons.
 * You can create separate `Dependency` instances to manage separate sets of
 * collections (for instance, one for testing). Or, you can use the single
 * [dependency] instance defined in this library to set up all the singletons
 * for your application.
 *
 *     Dependencies dependencies = new Dependencies();
 *     dependencies.setDependency(CatManager, catManager);
 *     dependencies.setDependency(DogManager, dogs);
 *
 *     ...
 *
 *     CatManager cats = dependencies[CatManager];
 *     cats.corale();
 *
 * When you want to set up a new series of services, for doing something like
 * executing tests with mocked out providers, you can use [runInZone]. So:
 *
 *     Dependencies dependencies = new Dependencies();
 *     dependencies.setDependency(CatManager, new MockCatManager());
 *     dependencies.setDependency(DogManager, new MockDogManager());
 *     dependencies.runInZone(executeTests);
 *
 * It will execute the method [executeTests] in a new Zone. Any queries to
 * [Dependencies.instance] will return the new dependencies set up for that
 * zone.
 */
class Dependencies {
  static Dependencies _global;

  static setGlobalInstance(Dependencies deps) {
    _global = deps;
  }

  /**
   * Get the current logical instance. This is the instance associated with the
   * current Zone, parent Zones, or the global instance.
   */
  static Dependencies get instance {
    Dependencies deps = Zone.current['dependencies'];
    return deps != null ? deps : _global;
  }

  Map<Type, dynamic> _instances = {};

  Dependencies();

  Dependencies get parent => _calcParent(Zone.current);

  dynamic getDependency(Type type) {
    if (_instances.containsKey(type)) {
      return _instances[type];
    }

    Dependencies parent = _calcParent(Zone.current);
    return parent != null ? parent.getDependency(type) : null;
  }

  void setDependency(Type type, dynamic instance) {
    _instances[type] = instance;
  }

  dynamic operator[](Type type) => getDependency(type);

  void operator[]=(Type type, dynamic instance) => setDependency(type, instance);

  /**
   * Return the [Type]s defined in this immediate [Dependencies] instance.
   */
  Iterable<Type> get types => _instances.keys;

  /**
   * Execute the given function in a new Zone. That zone is populated with the
   * dependencies of this object. Any requests for dependencies are first
   * satisfied with thie [Dependencies] object, and then delegate up to
   * [Dependencies] for parent Zones.
   */
  void runInZone(Function function) {
    Zone zone = Zone.current.fork(zoneValues: {'dependencies': this});
    zone.run(function);
  }

  /**
   * Determine the [Dependencies] instance that is the logical parent of the
   * [Dependencies] for the given [Zone].
   */
  Dependencies _calcParent(Zone zone) {
    if (this == _global) return null;

    Zone parentZone = zone.parent;
    if (parentZone == null) return _global;

    Dependencies deps = parentZone['dependencies'];
    if (deps == this) {
      return _calcParent(parentZone);
    } else {
      return deps != null ? deps : _global;
    }
  }
}
