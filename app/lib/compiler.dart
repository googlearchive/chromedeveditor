// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This library is a wrapper around the Dart to JavaScript (dart2js) compiler.
 */
library spark.compiler;

import 'dart:async';
import 'dart:html' as html;

import 'package:compiler_unsupported/compiler.dart' as compiler;

import 'sdk.dart';

// TODO: we'll want to re-work this so that the compile happens in an isolate
// (or a web worker). This library may then move to something like
// compiler_impl.dart. compiler.dart would become an interface to the compiler
// in the isolate, and we'd get a new top-level library in app/, called
// compiler_entry.dart.

// TODO:
class Compiler {

  Compiler() {

  }

  // TODO:
  bool get available => false;

  /**
   * Ensure the compiler is live and available. This makes sense in the context
   * of the bulk of the compiler living in another process.
   */
  Future<CompilerResult> pingCompiler() {
    return new Future.value(new CompilerResult._());
  }

  // TODO: args? FileEntry?
  Future<CompilerResult> compile() {
    // TODO: return success
    return new Future.value(new CompilerResult._());
  }

  Future<CompilerResult> compileString(String input) {
    _CompilerProvider provider = new _CompilerProvider.fromString(input);
    CompilerResult result = new CompilerResult._();

    return compiler.compile(provider.inputUri, DartSdk.getSdkUri(), null,
        provider.inputProvider,
        result._diagnosticHandler,
        [],
        result._outputProvider).then((String str) {
      return result;
    });
  }

  void dispose() {
    // TODO:

  }
}

class CompilerResult {
  List _warnings = [];
  StringBuffer _output;

  CompilerResult._();

  // TODO: a bit more nuanced then this
  bool get success => _warnings.isEmpty;

  List<CompilerWarning> get warnings => _warnings;

  String get output => _output == null ? null : _output.toString();

  void _diagnosticHandler(Uri uri, int begin, int end, String message,
      compiler.Diagnostic kind) {
    if (kind == compiler.Diagnostic.WARNING || kind == compiler.Diagnostic.ERROR) {
      warnings.add(new CompilerWarning._(uri, begin, end, message, kind));
    }
  }

  EventSink<String> _outputProvider(String name, String extension) {
    if (name.isEmpty && extension == 'js') {
      _output = new StringBuffer();
      return new _StringSink(_output);
    } else {
      return _NullSink.outputProvider(name, extension);
    }
  }
}

class CompilerWarning {
  final Uri uri;
  final int begin;
  final int end;
  final String message;
  final compiler.Diagnostic kind;

  CompilerWarning._(this.uri, this.begin, this.end, this.message, this.kind);

  bool get isWarningOrError => kind == compiler.Diagnostic.WARNING
      || kind == compiler.Diagnostic.ERROR;

  String toString() => "[${kind}] ${uri}: ${message}";
}

/// A sink that drains into /dev/null.
class _NullSink implements EventSink<String> {
  final String name;

  _NullSink(this.name);

  add(String value) { }

  void addError(Object error) { }

  void close() { }

  toString() => name;

  /// Convenience method for getting an [api.CompilerOutputProvider].
  static _NullSink outputProvider(String name, String extension) {
    return new _NullSink('$name.$extension');
  }
}

class _StringSink implements EventSink<String> {
  StringBuffer buffer;

  _StringSink(this.buffer);

  add(String value) => buffer.write(value);

  void addError(Object error) { }

  void close() { }
}

class _CompilerProvider {
  static final String INPUT_URI_TEXT = 'file:/__foo.dart';

  String input;

  _CompilerProvider.fromString(this.input);

  Uri get inputUri => Uri.parse(INPUT_URI_TEXT);

  Future<String> inputProvider(Uri uri) {
    if (uri.scheme == 'file') {
      if (uri.toString() == INPUT_URI_TEXT) {
        return new Future.value(input);
      }

      // TODO: file:

      return new Future.error('unhandled: ${uri.scheme}');
    } else if (uri.scheme == 'dart') {
      // TODO: package:

      return new Future.error('unhandled: ${uri.scheme}');
    } else if (uri.scheme == 'package') {
      // TODO: package:

      return new Future.error('unhandled: ${uri.scheme}');
    } else {
      return html.HttpRequest.getString(uri.toString());
    }
  }
}
