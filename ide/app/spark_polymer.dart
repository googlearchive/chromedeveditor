// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_polymer;

import 'package:bootjack/bootjack.dart' as bootjack;
import 'package:polymer/polymer.dart' as polymer;

import 'spark.dart';

import 'dart:html';
import 'package:spark_widgets/spark-overlay/spark-overlay.dart';

void main() {
  polymer.initPolymer().run(() {
    // TODO: hard-code developer mode to true for now.
    SparkPolymer spark = new SparkPolymer(true);
    spark.start();
  });
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

  @override
  void initEditorManager() => super.initEditorManager();

  @override
  void initEditorArea() => super.initEditorArea();

  @override
  void initSplitView() {
    // We're using a Polymer-based splitview, so disable the default.
  }

  // TODO(terry): Hookup overlay dialog.
  @override
  void showStatus(String text, {bool error: false}) {
    Element element = querySelector("#status");
    element.text = text;
    SparkOverlay overlay = querySelector("#spark-dialog");
    if (overlay != null) {
      overlay.toggle();
    }
  }

  @override
  void initFilesController() => super.initFilesController();

  @override
  void initLookAndFeel() {
    // Init the Bootjack library (a wrapper around Bootstrap).
    bootjack.Bootjack.useDefault();
  }

  @override
  void createActions() => super.createActions();

  @override
  void initToolbar() => super.initToolbar();

  @override
  void buildMenu() => super.buildMenu();

  //
  // - End parts of the parent's ctor.
  //
}
