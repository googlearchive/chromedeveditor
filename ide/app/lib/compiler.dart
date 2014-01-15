// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This library is a wrapper around the Dart to JavaScript (dart2js) compiler.
 */
library spark.compiler;

import 'dart:async';
import 'dart:html' as html;

import 'package:compiler/compiler/compiler.dart' as compiler;
export 'package:compiler/compiler/compiler.dart' show Diagnostic;

import 'sdk.dart';

// TODO: we should be tracking compilation times and sizes

/**
 * An interface to the dart2js compiler. A compiler object can process one
 * compile at a time. They are heavy-weight objects, and can be re-used once
 * a compile finishes. Subsequent compiles after the first one will be faster,
 * on the order of a 2x speedup.
 *
 * We'll want to re-work this so that the compile happens in an isolate (or a
 * web worker). This library may then move to something like compiler_impl.dart.
 * compiler.dart would become an interface to the compiler in the isolate, and
 * we'd get a new top-level library in app/, called compiler_entry.dart.
 *
 * TODO: host this in a separate isolate
 */
class Compiler {
  DartSdk _sdk;

  /**
   * Create and return a [Compiler] instance. These are heavy-weight objects.
   */
  static Future<Compiler> createCompiler() {
    return DartSdk.createSdk().then((DartSdk sdk) => new Compiler._(sdk));
  }

  Compiler._(this._sdk);

  /**
   * Ensure the compiler is live and available.
   */
  Future<CompilerResult> pingCompiler() {
    return new Future.value(new CompilerResult._());
  }

  Future<CompilerResult> compile(/*chrome.FileEntry*/ entry) {
    // TODO: implement

    return new Future.value(new CompilerResult._());
  }

  /**
   * Compile the given string and return the resulting [CompilerResult].
   */
  Future<CompilerResult> compileString(String input) {
    _CompilerProvider provider = new _CompilerProvider.fromString(_sdk, input);
    CompilerResult result = new CompilerResult._();
    DateTime startTime = new DateTime.now();

    return compiler.compile(provider.inputUri, new Uri(scheme: 'sdk', path: '/'), null,
        provider.inputProvider,
        result._diagnosticHandler,
        [],
        result._outputProvider).then((String str) {
      result._compileTime = new DateTime.now().difference(startTime);
      return result;
    });
  }

  /**
   * Dispose of this [Compiler] instance. [Compiler]'s are heavy-weight objects.
   */
  void dispose() {
    // TODO: close down the associated isolate process

  }
}

/**
 * The result of a dart2js compile.
 */
class CompilerResult {
  List<CompilerProblem> _problems = [];
  StringBuffer _output;
  Duration _compileTime;

  CompilerResult._();

  List<CompilerProblem> get problems => _problems;

  String get output => _output == null ? null : _output.toString();

  Duration get compileTime => _compileTime;

  /**
   * This is true if none of the reported problems were errors.
   */
  bool getSuccess() {
    return !_problems.any((p) => p.kind == compiler.Diagnostic.ERROR);
  }

  void _diagnosticHandler(Uri uri, int begin, int end, String message,
      compiler.Diagnostic kind) {
    if (kind == compiler.Diagnostic.WARNING || kind == compiler.Diagnostic.ERROR) {
      _problems.add(new CompilerProblem._(uri, begin, end, message, kind));
    }
  }

  EventSink<String> _outputProvider(String name, String extension) {
    if (name.isEmpty && extension == 'js') {
      _output = new StringBuffer();
      return new _StringSink(_output);
    } else {
      return new _NullSink('$name.$extension');
    }
  }
}

/**
 * An error, warning, hint, or into associated with a [CompilerResult].
 */
class CompilerProblem {
  /**
   * The Uri for the compilation unit; can be `null`.
   */
  final Uri uri;

  /**
   * The starting (0-based) character offset; can be `null`.
   */
  final int begin;

  /**
   * The ending (0-based) character offset; can be `null`.
   */
  final int end;

  final String message;
  final compiler.Diagnostic kind;

  CompilerProblem._(this.uri, this.begin, this.end, this.message, this.kind);

  bool get isWarningOrError => kind == compiler.Diagnostic.WARNING
      || kind == compiler.Diagnostic.ERROR;

  String toString() {
    if (uri == null) {
      return "${kind}: ${message}";
    } else {
      return "${kind} ${uri}: ${message}";
    }
  }
}

/**
 * A sink that drains into /dev/null.
 */
class _NullSink implements EventSink<String> {
  final String name;

  _NullSink(this.name);

  add(String value) { }

  void addError(Object error, [StackTrace stackTrace]) { }

  void close() { }

  toString() => name;
}

/**
 * Used to hold the output from dart2js.
 */
class _StringSink implements EventSink<String> {
  StringBuffer buffer;

  _StringSink(this.buffer);

  add(String value) => buffer.write(value);

  void addError(Object error, [StackTrace stackTrace]) { }

  void close() { }
}

/**
 * Instances of this class allow dart2js to resolve Uris to input sources.
 */
class _CompilerProvider {
  static final String INPUT_URI_TEXT = 'resource:/foo.dart';

  String input;
  DartSdk sdk;

  _CompilerProvider.fromString(this.sdk, this.input);

  Uri get inputUri => Uri.parse(INPUT_URI_TEXT);

  Future<String> inputProvider(Uri uri) {
    if (uri.scheme == 'resource') {
      if (uri.toString() == INPUT_URI_TEXT) {
        return new Future.value(input);
      } else {
        return new Future.error('unhandled: ${uri.scheme}');
      }
    } else if (uri.scheme == 'sdk') {
      final prefix = '/lib/';

      String path = uri.path;
      if (path.startsWith(prefix)) {
        path = path.substring(prefix.length);
      }

      String contents = sdk.getSourceForPath(path);
      if (contents != null) {
        return new Future.value(contents);
      } else {
        return new Future.error('file not found');
      }
    } else if (uri.scheme == 'file') {
      // TODO: file:

      return new Future.error('unhandled: ${uri.scheme}');
    } else if (uri.scheme == 'dart') {
      // TODO: dart:

      return new Future.error('unhandled: ${uri.scheme}');
    } else if (uri.scheme == 'package') {
      // TODO: package:

      return new Future.error('unhandled: ${uri.scheme}');
    } else {
      return html.HttpRequest.getString(uri.toString());
    }
  }
}
