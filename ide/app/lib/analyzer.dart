// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This library is an entry-point to the Dart analyzer package.
 */
library spark.analyzer;

import 'dart:async';

import 'package:analyzer/src/string_source.dart';
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
import 'utils.dart';

// TODO: investigate web workers and isolates

String analysisLiteralToString(StringLiteral literal) {
  if (literal is SimpleStringLiteral) {
    return stripQuotes(literal.value);
  } else {
    return literal.toString();
  }
}

//Future<AnalysisResult> analysisParseString(String contents, [chrome.FileEntry file]) {
//  Completer completer = new Completer();
//
//  AnalysisContext context = AnalysisEngine.instance.createAnalysisContext();
//
////  context.sourceFactory = new SourceFactory.con2(
////      [new DartUriResolver(dartSdk)]);
//
//  CompilationUnit unit;
//
//  try {
//    unit = context.parseCompilationUnit(
//        new AnalysisStringSource(context, contents, file));
//  } catch (e) {
//    unit = new CompilationUnit();
//  }
//
//  AnalysisResult result = new AnalysisResult(unit);
//
//  completer.complete(result);
//
//  return completer.future;
//}

// TODO:
// we have a string based source
// will need:
//   - an sdk based source
//   - a DOM file based source

/**
 * A Spark and Chrome Apps specific implementation of the [DartSdk] class.
 */
class ChromeDartSdk extends DartSdk {

  /**
   * Create and return a ChromeDartSdk asynchronously.
   */
  static Future<ChromeDartSdk> createSdk() {
    return spark.DartSdk.createSdk().then((spark.DartSdk sdk) {
      ChromeDartSdk chromeSdk = new ChromeDartSdk._(sdk);
      return chromeSdk._parseLibraries().then((_) => chromeSdk);
    });
  }

  final AnalysisContext context;

  spark.DartSdk _sdk;
  LibraryMap _libraryMap;

  ChromeDartSdk._(this._sdk): context = new AnalysisContextImpl();

  Source fromEncoding(ContentCache contentCache, UriKind kind, Uri uri) {
    // TODO: implement this method

  }

  SdkLibrary getSdkLibrary(String dartUri) => _libraryMap.getLibrary(dartUri);

  Source mapDartUri(String dartUri) {
    // TODO: implement

//    SdkLibrary library = getSdkLibrary(dartUri);
//    if (library == null) {
//      return null;
//    } else {
//      library
//    }
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

//class AnalysisResult {
//  CompilationUnit ast;
//
//  AnalysisResult(this.ast);
//
//  List<AnalysisError> get errors {
//    if (ast != null) {
//      // TODO:
//      return ast.errors;
//    } else {
//      return [];
//    }
//  }
//}

//class SdkSource implements Source {
//  final String _contents;
//  final String fullName;
//  final int modificationStamp;
//
//  SdkSource(this._contents, this.fullName)
//      : modificationStamp = new DateTime.now().millisecondsSinceEpoch;
//
//  bool operator==(Object object) {
//    if (object is StringSource) {
//      StringSource ssObject = object;
//      return ssObject._contents == _contents && ssObject.fullName == fullName;
//    }
//    return false;
//  }
//
//  bool exists() => true;
//
//  void getContents(Source_ContentReceiver receiver) =>
//      receiver.accept2(_contents, modificationStamp);
//
//  String get encoding => throw new UnsupportedError("StringSource doesn't support "
//      "encoding.");
//
//  String get shortName => fullName;
//
//  UriKind get uriKind => throw new UnsupportedError("StringSource doesn't support "
//      "uriKind.");
//
//  int get hashCode => _contents.hashCode ^ fullName.hashCode;
//
//  bool get isInSystemLibrary => false;
//
//  Source resolveRelative(Uri relativeUri) => throw new UnsupportedError(
//      "StringSource doesn't support resolveRelative.");
//}

class FileSource implements Source {
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
