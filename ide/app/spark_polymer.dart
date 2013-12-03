// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_polymer;

import 'package:bootjack/bootjack.dart' as bootjack;
import 'package:polymer/polymer.dart' as polymer;

import 'spark.dart';

void main() {
  // TODO: hard-code developer mode to true for now.
  SparkPolymer spark = new SparkPolymer(true);
  spark.start();
}

class SparkPolymer extends Spark {
  SparkPolymer(bool developerMode) : super(developerMode);

  //
  // Override some parts of the parent's ctor:
  //

  @override
  String get appName => super.appName + "Polymer";

  @override
  void initAnalytics() => super.initAnalytics();

  @override
  void initWorkspace() => super.initWorkspace();

  @override
  void initEditor() => super.initEditor();

  // TEMP:
  @override
  void initEditorManager() => null; //super.initEditorManager();

  // TEMP:
  @override
  void initEditorArea() => null; //super.initEditorArea();

  // We're using a Polymer-based splitview, so disable the default.
  @override
  void initSplitView() => null;

  // TEMP:
  @override
  void initFilesController() => null; //super.initFilesController();

  @override
  void initLookAndFeel() {
    // Init the Polymer library.
    polymer.initPolymer();
    // Init the Bootjack library (a wrapper around Bootstrap).
    bootjack.Bootjack.useDefault();
  }

  // TEMP:
  @override
  void createActions() => null; //super.createActions();

  // TEMP:
  @override
  void initToolbar() => null; //super.initToolbar();

  // TEMP:
  @override
  void buildMenu() => null; //super.buildMenu();

  //
  // - End parts of the parent's ctor.
  //
}
