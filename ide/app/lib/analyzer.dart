// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This library is an entry-point to the Dart analyzer package.
 */
library spark.analyzer;

import 'dart:async';

import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/error.dart';
import 'package:analyzer/src/generated/java_core.dart';
import 'package:analyzer/src/generated/parser.dart';
import 'package:analyzer/src/generated/scanner.dart';
import 'package:analyzer/src/generated/sdk.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:chrome_gen/chrome_app.dart' as chrome;

export 'package:analyzer/src/generated/ast.dart';
export 'package:analyzer/src/generated/error.dart';

import 'sdk.dart' as spark;

// TODO: investigate web workers and isolates

Completer<ChromeDartSdk> _sdkCompleter;

/**
 * Create and return a ChromeDartSdk asynchronously.
 */
Future<ChromeDartSdk> createSdk() {
  if (_sdkCompleter != null) {
    return _sdkCompleter.future;
  }

  _sdkCompleter = new Completer();

  spark.DartSdk.createSdk().then((spark.DartSdk sdk) {
    ChromeDartSdk chromeSdk = new ChromeDartSdk._(sdk);
    chromeSdk._parseLibraries().then((_) => _sdkCompleter.complete(chromeSdk));
  });

  return _sdkCompleter.future;
}

/**
 * Given a string representing Dart source, return a result comsisting of an AST
 * and a list of errors.
 *
 * The API for this method is asynchronous; the actual implementation is
 * synchronous. In the future both API and implementation will be asynchronous.
 */
Future<AnalyzerResult> analyzeString(ChromeDartSdk sdk, String contents,
    {bool performResolution: true}) {
  Completer completer = new Completer();

  // TODO: clean this up
  //AnalysisEngine.instance.createAnalysisContext();
  AnalysisContext context = new AnalysisContextImpl();

  context.sourceFactory = new SourceFactory.con2([new DartUriResolver(sdk)]);

  CompilationUnit unit;
  StringSource source = new StringSource(contents, '<StringSource>');

  try {
    unit = context.parseCompilationUnit(source);
  } catch (e) {
    unit = new CompilationUnit();
  }

  if (performResolution) {
    context.computeErrors(source);
  }

  AnalyzerResult result = new AnalyzerResult(unit, context.getErrors(source));

  completer.complete(result);

  return completer.future;
}

/**
 * A tuple of an AST and a list of errors.
 */
class AnalyzerResult {
  final CompilationUnit ast;
  final AnalysisErrorInfo errorInfo;

  AnalyzerResult(this.ast, this.errorInfo);

  List<AnalysisError> get errors => errorInfo.errors;
}

/**
 * A Spark and Chrome Apps specific implementation of the [DartSdk] class.
 */
class ChromeDartSdk extends DartSdk {
  final AnalysisContext context;

  spark.DartSdk _sdk;
  LibraryMap _libraryMap;

  ChromeDartSdk._(this._sdk): context = new AnalysisContextImpl();

  Source fromEncoding(ContentCache contentCache, UriKind kind, Uri uri) {
    // TODO: implement

    throw new UnimplementedError('fromEncoding');
  }

  SdkLibrary getSdkLibrary(String dartUri) => _libraryMap.getLibrary(dartUri);

  /**
   * Return the source representing the library with the given `dart:` URI, or
   * `null` if the given URI does not denote a library in this SDK.
   */
  Source mapDartUri(String dartUri) {
    SdkLibrary library = getSdkLibrary(dartUri);

    return library == null ? null : new SdkSource(_sdk, library.path);
  }

  List<SdkLibrary> get sdkLibraries => _libraryMap.sdkLibraries;

  String get sdkVersion => _sdk.version;

  List<String> get uris => _libraryMap.uris;

  Future _parseLibraries() {
    return _sdk.libDirectory.getChild('_internal').then((spark.SdkDirectory dir) {
      return dir.getChild('libraries.dart').then((spark.SdkFile file) {
        return file.getContents().then((String contents) {
          _libraryMap = _parseLibrariesMap(contents);
          return _libraryMap;
        });
      });
    });
  }

  LibraryMap _parseLibrariesMap(String contents) {
    List<bool> foundError = [false];
    NullAnalysisErrorListener errorListener = new NullAnalysisErrorListener();
    Source source = new StringSource(contents, 'lib/_internal/libraries.dart');
    Scanner scanner = new Scanner(source, new CharSequenceReader(new CharSequence(contents)), errorListener);
    Parser parser = new Parser(source, errorListener);
    CompilationUnit unit = parser.parseCompilationUnit(scanner.tokenize());
    SdkLibrariesReader_LibraryBuilder libraryBuilder = new SdkLibrariesReader_LibraryBuilder();
    if (!errorListener.foundError) {
      unit.accept(libraryBuilder);
    }
    return libraryBuilder.librariesMap;
  }
}

/**
 * An implementation of [Source] that's based on an in-memory Dart string.
 */
class StringSource extends Source {
  final String _contents;
  final String fullName;
  final int modificationStamp;

  StringSource(this._contents, this.fullName)
      : modificationStamp = new DateTime.now().millisecondsSinceEpoch;

  bool operator==(Object object) {
    if (object is StringSource) {
      StringSource ssObject = object;
      return ssObject._contents == _contents && ssObject.fullName == fullName;
    }
    return false;
  }

  bool exists() => true;

  void getContents(Source_ContentReceiver receiver) =>
      receiver.accept2(_contents, modificationStamp);

  String get encoding => 'UTF-8';

  String get shortName => fullName;

  UriKind get uriKind => throw new UnsupportedError("StringSource doesn't support "
      "uriKind.");

  int get hashCode => _contents.hashCode ^ fullName.hashCode;

  bool get isInSystemLibrary => false;

  Source resolveRelative(Uri relativeUri) => throw new UnsupportedError(
      "StringSource doesn't support resolveRelative.");
}

/**
 * A [Source] implementation based of a file in the SDK.
 */
class SdkSource extends Source {
  final String fullName;
  final spark.DartSdk _sdk;

  SdkSource(this._sdk, this.fullName);

  bool operator==(Object object) {
    if (object is SdkSource) {
      return object.fullName == fullName;
    } else {
      return false;
    }
  }

  bool exists() => true;

  void getContents(Source_ContentReceiver receiver) {
    // TODO: an unglamorous hack for now
    String cachedSource = _sdk.getCachedSource(fullName);

    if (cachedSource != null) {
      receiver.accept2(cachedSource, modificationStamp);
    } else {
      throw new UnimplementedError('getContents');
    }
  }

  String get encoding => 'UTF-8';

  String get shortName {
    // TODO: create a utility method
    int index = fullName.lastIndexOf('/');
    return index == -1 ? fullName : fullName.substring(index + 1);
  }

  UriKind get uriKind => UriKind.DART_URI;

  int get hashCode => fullName.hashCode;

  bool get isInSystemLibrary => true;

  Source resolveRelative(Uri relativeUri) {
    // TODO: create a utility method
    String path = fullName.substring(0, fullName.lastIndexOf('/') + 1) + relativeUri.path;

    return new SdkSource(_sdk, path);
  }

  // TODO: will this work as a modification stamp for sdk sources?
  int get modificationStamp => 0;

  String toString() => fullName;
}

/**
 * A [Source] implementation based on HTML FileEntrys.
 */
class FileSource extends Source {
  final chrome.ChromeFileEntry file;

  FileSource(this.file);

  bool operator==(Object object) {
    if (object is FileSource) {
      FileSource ssObject = object;
      return ssObject.fullName == fullName;
    } else {
      return false;
    }
  }

  bool exists() {
    // TODO:

     throw new UnimplementedError('exists');
  }

  void getContents(Source_ContentReceiver receiver) {
    // TODO:

    throw new UnimplementedError('getContents');
  }

  String get encoding {
    // TODO:

    throw new UnimplementedError('encoding');
  }

  String get shortName => file.name;

  String get fullName => file.fullPath;

  UriKind get uriKind => UriKind.FILE_URI;

  int get hashCode => fullName.hashCode;

  bool get isInSystemLibrary => false;

  Source resolveRelative(Uri relativeUri) {
    // TODO:

    throw new UnimplementedError('resolveRelative');
  }

  int get modificationStamp {
    // TODO:

    throw new UnimplementedError('modificationStamp');
  }

  String toString() => fullName;
}

class NullAnalysisErrorListener implements AnalysisErrorListener {
  bool foundError = false;

  NullAnalysisErrorListener();

  void onError(AnalysisError error) {
    foundError = true;
  }
}

class SdkLibrariesReader_LibraryBuilder extends RecursiveASTVisitor<Object> {
  /**
   * The prefix added to the name of a library to form the URI used in code to reference the
   * library.
   */
  static String _LIBRARY_PREFIX = "dart:";

  /**
   * The name of the optional parameter used to indicate whether the library is an implementation
   * library.
   */
  static String _IMPLEMENTATION = "implementation";

  /**
   * The name of the optional parameter used to indicate whether the library is documented.
   */
  static String _DOCUMENTED = "documented";

  /**
   * The name of the optional parameter used to specify the category of the library.
   */
  static String _CATEGORY = "category";

  /**
   * The name of the optional parameter used to specify the platforms on which the library can be
   * used.
   */
  static String _PLATFORMS = "platforms";

  /**
   * The value of the [PLATFORMS] parameter used to specify that the library can
   * be used on the VM.
   */
  static String _VM_PLATFORM = "VM_PLATFORM";

  /**
   * The library map that is populated by visiting the AST structure parsed from the contents of
   * the libraries file.
   */
  final LibraryMap librariesMap = new LibraryMap();

  Object visitMapLiteralEntry(MapLiteralEntry node) {
    String libraryName = null;
    Expression key = node.key;
    if (key is SimpleStringLiteral) {
      libraryName = "${_LIBRARY_PREFIX}${key.value}";
    }
    Expression value = node.value;
    if (value is InstanceCreationExpression) {
      SdkLibraryImpl library = new SdkLibraryImpl(libraryName);
      List<Expression> arguments = (value).argumentList.arguments;
      for (Expression argument in arguments) {
        if (argument is SimpleStringLiteral) {
          library.path = argument.value;
        } else if (argument is NamedExpression) {
          String name = argument.name.label.name;
          Expression expression = argument.expression;
          if (name == _CATEGORY) {
            library.category = ((expression as SimpleStringLiteral)).value;
          } else if (name == _IMPLEMENTATION) {
            library.implementation = ((expression as BooleanLiteral)).value;
          } else if (name == _DOCUMENTED) {
            library.documented = ((expression as BooleanLiteral)).value;
          } else if (name == _PLATFORMS) {
            if (expression is SimpleIdentifier) {
              String identifier = expression.name;
              if (identifier == _VM_PLATFORM) {
                library.setVmLibrary();
              } else {
                library.setDart2JsLibrary();
              }
            }
          }
        }
      }
      librariesMap.setLibrary(libraryName, library);
    }
    return null;
  }
}
