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
export 'package:compiler_unsupported/compiler.dart' show Diagnostic;

import '../dart/sdk.dart';

/**
 * An interface to the dart2js compiler. A compiler object can process one
 * compile at a time. They are heavy-weight objects, and can be re-used once
 * a compile finishes. Subsequent compiles after the first one will be faster,
 * on the order of a 2x speedup.
 */
class Compiler {
  DartSdk _sdk;
  ContentsProvider _contentsProvider;

  /**
   * Create and return a [Compiler] instance. These are heavy-weight objects.
   */
  static Future<Compiler> createCompiler(ContentsProvider contentsProvider) {
    return DartSdk.createSdk().then(
        (DartSdk sdk) => new Compiler._(sdk, contentsProvider));
  }

  static Compiler createCompilerFrom(DartSdk sdk,
                                     ContentsProvider contentsProvider) {
    return new Compiler._(sdk, contentsProvider);
  }

  Compiler._(this._sdk, this._contentsProvider);

  Future<CompilerResult> compileFile(String fileUuid, {bool csp: false}) {
    _CompilerProvider provider =
        new _CompilerProvider.fromUuid(_sdk, _contentsProvider, fileUuid);

    CompilerResult result = new CompilerResult._(csp).._start();

    return compiler.compile(
        provider.getInitialUri(),
        new Uri(scheme: 'sdk', path: '/'),
        new Uri(scheme: 'package', path: '/'),
        provider.inputProvider,
        result._diagnosticHandler,
        [],
        result._outputProvider).then((_) => result._stop());
  }

  /**
   * Compile the given string and return the resulting [CompilerResult].
   */
  Future<CompilerResult> compileString(String input) {
    _CompilerProvider provider = new _CompilerProvider.fromString(_sdk, input);

    CompilerResult result = new CompilerResult._().._start();

    return compiler.compile(
        provider.getInitialUri(),
        new Uri(scheme: 'sdk', path: '/'),
        new Uri(scheme: 'package', path: '/'),
        provider.inputProvider,
        result._diagnosticHandler,
        [],
        result._outputProvider).then((_) => result._stop());
  }
}

/**
 * The result of a dart2js compile.
 */
class CompilerResult {
  final bool csp;
  List<CompilerProblem> _problems = [];
  StringBuffer _output;
  Duration _compileTime;
  DateTime _startTime;

  CompilerResult._([this.csp = false]);

  void _start() {
    _startTime = new DateTime.now();
  }

  CompilerResult _stop() {
    _compileTime = new DateTime.now().difference(_startTime);
    return this;
  }

  List<CompilerProblem> get problems => _problems;

  String get output => _output == null ? null : _output.toString();

  bool get hasOutput => output != null;

  Duration get compileTime => _compileTime;

  /**
   * This is true if none of the reported problems were errors.
   */
  bool getSuccess() {
    return !_problems.any((p) => p.kind == compiler.Diagnostic.ERROR);
  }

  void _diagnosticHandler(Uri uri, int begin, int end, String message,
      compiler.Diagnostic kind) {
    // Convert dart2js crash types to our error type.
    if (kind == compiler.Diagnostic.CRASH) kind = compiler.Diagnostic.ERROR;

    if (kind == compiler.Diagnostic.WARNING || kind == compiler.Diagnostic.ERROR) {
      _problems.add(new CompilerProblem._(uri, begin, end, message, kind));
    }
  }

  EventSink<String> _outputProvider(String name, String extension) {
    if (!csp && name.isEmpty && extension == 'js') {
      _output = new StringBuffer();
      return new _StringSink(_output);
    } else if (csp && name.isEmpty && extension == 'precompiled.js') {
      _output = new StringBuffer();
      return new _StringSink(_output);
    } else {
      return new _NullSink('$name.$extension');
    }
  }

  CompilerResult.fromMap(Map data) : csp = false {
    _compileTime = new Duration(milliseconds: data['compileMilliseconds']);
    String outputString = data['output'];
    _output = (outputString == null) ? null : new StringBuffer(outputString);

    for (Map problem in data['problems']) {
      problems.add(new CompilerProblem.fromMap(problem));
    }
  }

  Map toMap() {
    List responseProblems = problems.map((p) => p.toMap()).toList();

    return {
      "compileMilliseconds": compileTime.inMilliseconds,
      "output": output,
      "problems": responseProblems,
    };
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
      return "[${kind}] ${message}";
    } else {
      return "[${kind}] ${message} (${uri})";
    }
  }

  CompilerProblem.fromMap(Map data) :
    begin = data['begin'],
    end = data['end'],
    message = data['message'],
    uri = new Uri.file(data['uri']),
    kind = _diagnosticFrom(data['kind']);

  Map toMap() {
    return {
      "begin": begin,
      "end": end,
      "message": message,
      "uri": (uri == null) ? "" : uri.path,
      "kind": kind.name
    };
  }

  static compiler.Diagnostic _diagnosticFrom(String name) {
    if (name == 'warning') return compiler.Diagnostic.WARNING;
    if (name == 'hint') return compiler.Diagnostic.HINT;
    if (name == 'into') return compiler.Diagnostic.INFO;
    if (name == 'verbose info') return compiler.Diagnostic.VERBOSE_INFO;
    if (name == 'crash') return compiler.Diagnostic.CRASH;
    return compiler.Diagnostic.ERROR;
  }
}

abstract class ContentsProvider {
  Future<String> getFileContents(String uuid);
  Future<String> getPackageContents(String relativeUuid, String packageRef);
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
  static final String _INPUT_URI_TEXT = 'resource:/foo.dart';

  final String textInput;
  final String uuidInput;
  final DartSdk sdk;
  ContentsProvider provider;

  _CompilerProvider.fromString(this.sdk, this.textInput) : uuidInput = null;

  _CompilerProvider.fromUuid(this.sdk, this.provider, this.uuidInput) :
      textInput = null;

  Uri getInitialUri() {
    if (textInput != null) {
      return Uri.parse(_CompilerProvider._INPUT_URI_TEXT);
    } else {
      return new Uri(scheme: 'file', path: uuidInput);
    }
  }

  Future<String> inputProvider(Uri uri) {
    if (uri.scheme == 'resource') {
      if (uri.toString() == _INPUT_URI_TEXT) {
        return new Future.value(textInput);
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
      return provider.getFileContents(uri.path);
    } else if (uri.scheme == 'package') {
      if (uuidInput == null) return new Future.error('file not found');

      // Convert `package:/foo/foo.dart` to `package:foo/foo.dart`.
      return provider.getPackageContents(
          uuidInput, 'package:${uri.path.substring(1)}');
    } else {
      return html.HttpRequest.getString(uri.toString());
    }
  }
}
