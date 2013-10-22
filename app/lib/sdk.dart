// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A library to allow access to the Dart SDK. Specifically, this class exposes
 * the source code for the dart: libraries fro the `dart-sdk/lib` directory.
 * Having the SDK source is necessary for:
 *
 * * dart2js to compile against (otherwise it won't know anything about say
 *    dart:core String)
 * * the analyzer to analyze against, so we can get warnings about incorrect
 *    API usage
 * * the user to navigate to when doing things like exploring the dart apis
 */
library spark.sdk;

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:chrome_gen/chrome_app.dart' as chrome_gen;

/**
 * Return the contents of the file at the given path. The path is relative to
 * the Chrome app's directory.
 */
Future<String> _getContents(String path) {
  return html.HttpRequest.getString(chrome_gen.runtime.getURL(path));
}

// TODO(devoncarew): parse the sdk/lib/_internal/libraries.dart file?

/**
 * This class represents the Dart SDK as build into Spark. It allows you to
 * query the SDK version and to get the contents of the included Dart libraries.
 */
class DartSdk extends SdkDirectory {
  final String version;

  SdkDirectory _libDirectory;

  /**
   * Return the `sdk/lib` directory.
   */
  SdkDirectory get libDirectory => _libDirectory;

  /**
   * Return whether the Dart SDK is present.
   */
  bool get available => libDirectory != null;

  /**
   * Create a return a [DartSdk]. Generally, an application will only have one
   * of these object's instantiated. They are however relatively lightweight
   * objects.
   */
  static Future<DartSdk> createSdk() {
    DartSdk sdk;

    return _getContents('sdk/version').then((String verContents) {
      sdk = new DartSdk._(version: verContents.trim());
      return sdk.getChild('lib');
    }).then((SdkDirectory dir) {
      sdk._libDirectory = dir;
      return sdk;
    }).catchError((e) {
      return new DartSdk._(version: '');
    });
  }

  DartSdk._({this.version}): super._(null, 'sdk');
}

/**
 * An abstract SDK entity; the parent class of [SdkFile] and [SdkDirectory].
 */
abstract class SdkEntity {
  /**
   * The full path of this entity (`sdk/lib/core/string.dart`).
   */
  final String path;

  /**
   * The parent of this entity.
   */
  final SdkDirectory parent;

  SdkEntity._(this.parent, this.path);

  /**
   * The name of this entity (`string.dart`).
   */
  String get name {
    int index = path.lastIndexOf('/');
    return index == -1 ? path : path.substring(index + 1);
  }
}

/**
 * An SDK file.
 */
class SdkFile extends SdkEntity {
  SdkFile._(SdkDirectory parent, String path): super._(parent, path);

  /**
   * Return the contents of this file.
   */
  Future<String> getContents() => _getContents(path);
}

/**
 * An SDK directory entry.
 */
class SdkDirectory extends SdkEntity {
  List<SdkEntity> _children;

  SdkDirectory._(SdkDirectory parent, String path): super._(parent, path);

  /**
   * Return the given named child of this directory.
   */
  Future<SdkEntity> getChild(String name) {
    return getChildren().then((List<SdkEntity> children) {
      return children.firstWhere(
          (c) => c.name == name,
          orElse: () => null);
    });
  }

  /**
   * Return the children of this directory.
   */
  Future<List<SdkEntity>> getChildren() {
    if (_children != null) {
      return new Future.value(_children);
    } else {
      Completer completer = new Completer();

      _getContents("${path}/.files").then((String value) {
        _children = _parseJson(value);
        completer.complete(_children);
      }).catchError((_) {
        _children = new List<SdkEntity>();
        completer.complete(_children);
      });

      return completer.future;
    }
  }

  List<SdkEntity> _parseJson(String jsonText) {
    List<SdkEntity> results = new List<SdkEntity>();

    var values = JSON.decode(jsonText);

    for (String value in values) {
      if (value.endsWith('/')) {
        results.add(new SdkDirectory._(this,
            "${path}/${value.substring(0, value.length - 1)}"));
      } else {
        results.add(new SdkFile._(this,"${path}/${value}"));
      }
    }

    return results;
  }
}
