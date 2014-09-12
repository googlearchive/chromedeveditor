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
import 'package:analyzer/src/generated/parser.dart';
import 'package:analyzer/src/generated/scanner.dart';
import 'package:analyzer/src/generated/sdk.dart';
import 'package:analyzer/src/generated/source.dart';

export 'package:analyzer/src/generated/ast.dart';
export 'package:analyzer/src/generated/element.dart';
export 'package:analyzer/src/generated/error.dart';
export 'package:analyzer/src/generated/source.dart';

import 'services_common.dart' as common;
import '../dart/sdk.dart' as sdk;

/**
 * Create and return a ChromeDartSdk.
 */
ChromeDartSdk createSdk(sdk.DartSdk dartSdk) {
  ChromeDartSdk chromeSdk = new ChromeDartSdk._(dartSdk);
  chromeSdk._parseLibrariesFile();
  return chromeSdk;
}

/**
 * Given a string representing Dart source, return a result consisting of an AST
 * and a list of errors.
 *
 * The API for this method is asynchronous; the actual implementation is
 * synchronous. In the future both API and implementation will be asynchronous.
 */
Future<AnalyzerResult> analyzeString(ChromeDartSdk sdk, String contents) {
  Completer completer = new Completer();

  AnalysisContext context = AnalysisEngine.instance.createAnalysisContext();
  context.sourceFactory = new SourceFactory([new DartUriResolver(sdk)]);

  CompilationUnit unit;
  StringSource source = new StringSource(contents, '<StringSource>');

  try {
    unit = context.parseCompilationUnit(source);
  } catch (e) {
    unit = null;
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

  LineInfo_Location getLineInfo(AnalysisError error) {
    return errorInfo.lineInfo.getLocation(error.offset);
  }

  String toString() => 'AnalyzerResult[${errorInfo.errors.length} issues]';
}

class AnalysisResultUuid {
  /**
   * A Map from file uuids to list of associated errors.
   */
  final Map<String, List<common.AnalysisError>> _errorMap = {};

  AnalysisResultUuid();

  void addErrors(String uuid, List<common.AnalysisError> errors) {
    // Ignore warnings from imported packages.
    if (!uuid.startsWith('package:')) {
      _errorMap[uuid] = errors;
    }
  }

  Map toMap() {
    Map m = {};
    _errorMap.forEach((String uuid, List<common.AnalysisError> errors) {
      m[uuid] = errors.map((e) => e.toMap()).toList();
    });
    return m;
  }
}

/**
 * A Spark and Chrome Apps specific implementation of the [DartSdk] class.
 */
class ChromeDartSdk extends DartSdk {
  final AnalysisContext context;

  final sdk.DartSdk _sdk;
  LibraryMap _libraryMap;

  ChromeDartSdk._(this._sdk): context = new AnalysisContextImpl() {
    context.sourceFactory = new SourceFactory([]);
  }

  /**
   * Return a source representing the given `file:` URI if the file is in this SDK,
   * or `null` if the file is not in this SDK.
   */
  @override
  Source fromFileUri(Uri uri) {
    print("> ChromeDartSdk.fromFileUri(${uri})");
    Source result = mapDartUri(uri.toString());
    print("< ChromeDartSdk.fromFileUri(${uri}): ${result == null ? 'null' : result.uri}");
    return result;
  }

  /**
   * Return the library representing the library with the given `dart:` URI, or `null`
   * if the given URI does not denote a library in this SDK.
   * The [dartUri] string is expected to have a "dart:library_name" format, for example,
   * "dart:core", "dart:html", etc.
   */
  @override
  SdkLibrary getSdkLibrary(String dartUri) {
    SdkLibrary result = _libraryMap.getLibrary(dartUri);
    print("= ChromeDartSdk.getSdkLibrary(${dartUri}): ${result== null ? 'null' : result.path}");
    return result;
  }

  /**
   * Return the source representing the library with the given `dart:`
   * [dartUri], or `null` if the given URI does not denote a library
   * in this SDK.
   *
   * Note: As of version 0.22 of the `analyzer` package, this method
   * must support mapping a simple library uri (e.g "dart:html_common")
   * as well as a libray uri + "/" + a relative path of a file
   * in that library (e.g. "dart:html_common/metadata.dart").
   * In any case, the first part of the URI string (up to the optional "/")
   * is always a library name.
   *
   * Note: This method is mostly a copy-paste of the same method in
   * [DirectoryBasedDartSdk] in the `analyzer` package.
   */
  @override
  Source mapDartUri(String dartUri) {
    print("> ChromeDartSdk.mapDartUri(${dartUri})");

    // The URI scheme is always "dart"
    Uri uri = parseUriWithException(dartUri);
    assert(uri.scheme == DartUriResolver.DART_SCHEME);

    // The string up to "/" is the library name, the rest (optional)
    // is the relative path of the source file in that library.
    int index = dartUri.indexOf("/");
    String libraryName;
    String relativePath;
    if (index < 0) {
      libraryName = dartUri;
      relativePath = "";
    } else {
      libraryName = dartUri.substring(0, index);
      relativePath = dartUri.substring(index + 1);
    }

    SdkLibrary library = getSdkLibrary(libraryName);
    Source result;
    if (library == null) {
      result = null;
    } else {
      // If we have a relative path, the actual path of the source file
      // is the directory component of the main source file of the library
      // concatenated to the relative path of this source file.
      String path = library.path;
      if (relativePath.isNotEmpty) {
        path = dirname(path) + "/" + relativePath;
      }
      result = new SdkSource(_sdk, uri, path);
    }
    print("< ChromeDartSdk.mapDartUri(${dartUri}): ${result == null ? 'null' : result}");
    return result;
  }

  @override
  List<SdkLibrary> get sdkLibraries => _libraryMap.sdkLibraries;

  @override
  String get sdkVersion => _sdk.version;

  @override
  List<String> get uris => _libraryMap.uris;

  void _parseLibrariesFile() {
    String contents = _sdk.getSourceForPath('_internal/libraries.dart');
    _libraryMap = _parseLibrariesMap(contents);
  }

  LibraryMap _parseLibrariesMap(String contents) {
    SimpleAnalysisErrorListener errorListener =
        new SimpleAnalysisErrorListener();
    Source source = new StringSource(contents, 'lib/_internal/libraries.dart');
    Scanner scanner =
        new Scanner(source, new CharSequenceReader(contents), errorListener);
    Parser parser = new Parser(source, errorListener);
    CompilationUnit unit = parser.parseCompilationUnit(scanner.tokenize());
    SdkLibrariesReader_LibraryBuilder libraryBuilder =
        new SdkLibrariesReader_LibraryBuilder(false);

    if (!errorListener.foundError) {
      unit.accept(libraryBuilder);
    }
    return libraryBuilder.librariesMap;
  }
}

class AnalysisEnginePrintLogger implements Logger {
  @override
  void logError(String message) {
    print("error: ${message}");
  }

  @override
  void logError2(String message, Exception exception) {
    print("error2: ${message} ${exception}");
  }

  @override
  void logInformation(String message) {
    print("info: ${message}");
  }

  @override
  void logInformation2(String message, Exception exception) {
    print("info2: ${message} ${exception}");
  }
}

/**
 * A wrapper around an analysis context. There is a one-to-one mapping between
 * projects, on the DOM side, and analysis contexts.
 */
class ProjectContext {
  static const int MAX_CACHE_SIZE = 256;
  static final int DEFAULT_CACHE_SIZE = AnalysisOptionsImpl.DEFAULT_CACHE_SIZE;

  // The id for the project this context is associated with.
  final String id;
  final ChromeDartSdk sdk;
  final common.ContentsProvider provider;

  AnalysisContext context;

  final Map<String, FileSource> _sources = {};

  ProjectContext(this.id, this.sdk, this.provider) {
    // TODO(rpaquay): For debugging purposes only.
    AnalysisEngine.instance.logger = new AnalysisEnginePrintLogger();
    context = AnalysisEngine.instance.createAnalysisContext();
    context.sourceFactory = new SourceFactory([
        new CustomDartUriResolver(sdk),
        new PackageUriResolver(this),
        new FileUriResolver(this)
    ]);
  }

  Future<AnalysisResultUuid> processChanges(List<String> addedUuids,
      List<String> changedUuids, List<String> deletedUuids) {

    ChangeSet changeSet = new ChangeSet();

    // added
    for (String uuid in addedUuids) {
      _sources[uuid] = new FileSource(this, uuid);
      changeSet.addedSource(_sources[uuid]);
    }

    // changed
    for (String uuid in changedUuids) {
      if (_sources[uuid] != null) {
        changeSet.changedSource(_sources[uuid]);
        _sources[uuid].setContents(null);
      } else {
        _sources[uuid] = new FileSource(this, uuid);
        changeSet.addedSource(_sources[uuid]);
      }
    }

    // deleted
    for (String uuid in deletedUuids) {
      if (_sources[uuid] != null) {
        // TODO(devoncarew): Should we set this to deleted or remove the FileSource?
        _sources[uuid]._exists = false;
        _sources[uuid].setContents(null);
        changeSet.removedSource(_sources.remove(uuid));
      }
    }

    // Increase the cache size before we process the changes. We set the size
    // back down to the default after analysis is complete.
    _setCacheSize(MAX_CACHE_SIZE);

    context.applyChanges(changeSet);

    Completer<AnalysisResultUuid> completer = new Completer();

    _populateSources().then((_) {
      _processChanges(completer, new AnalysisResultUuid());
    }).catchError((e) {
      _setCacheSize(DEFAULT_CACHE_SIZE);
      completer.completeError(e);
    });

    return completer.future;
  }

  FileSource getSource(String uuid) {
    return _sources[uuid];
  }

  void _processChanges(Completer<AnalysisResultUuid> completer,
      AnalysisResultUuid analysisResult) {
    try {
      AnalysisResult result = context.performAnalysisTask();
      List<ChangeNotice> notices = result.changeNotices;

      while (notices != null) {
        for (ChangeNotice notice in notices) {
          if (notice.source is! FileSource) continue;

          FileSource source = notice.source;
          analysisResult.addErrors(
              source.uuid, _convertErrors(notice, notice.errors));
        }

        result = context.performAnalysisTask();
        notices = result.changeNotices;
      }

      _setCacheSize(DEFAULT_CACHE_SIZE);
      completer.complete(analysisResult);
    } catch (e, st) {
      _setCacheSize(DEFAULT_CACHE_SIZE);
      completer.completeError(e, st);
    }
  }

  /**
   * Populate the contents for the [FileSource]s.
   */
  Future _populateSources() {
    List<Future> futures = [];

    _sources.forEach((String uuid, FileSource source) {
      if (source.exists() && source._strContents == null) {
        Future f;

        if (uuid.startsWith('package:')) {
          f = provider.getPackageContents(id, uuid).then((String str) {
            source.setContents(str);
          });
        } else {
          f = provider.getFileContents(uuid).then((String str) {
            source.setContents(str);
          });
        }

        futures.add(f);
      }
    });

    return Future.wait(futures);
  }

  void _setCacheSize(int size) {
    var options = new AnalysisOptionsImpl();
    options.cacheSize = size;
    context.analysisOptions = options;
  }
}

List<common.AnalysisError> _convertErrors(
    AnalysisErrorInfo errorInfo, List<AnalysisError> errors) {
  return errors.map((error) => _convertError(errorInfo, error)).toList();
}

common.AnalysisError _convertError(AnalysisErrorInfo errorInfo, AnalysisError error) {
  common.AnalysisError err = new common.AnalysisError();
  err.message = error.message;
  err.offset = error.offset;
  LineInfo_Location location = errorInfo.lineInfo.getLocation(error.offset);
  err.lineNumber = location.lineNumber;
  err.length = error.length;
  err.errorSeverity = _errorSeverityToInt(error.errorCode.errorSeverity);
  return err;
}

int _errorSeverityToInt(ErrorSeverity severity) {
  if (severity == ErrorSeverity.ERROR) {
    return common.ErrorSeverity.ERROR;
  } else  if (severity == ErrorSeverity.WARNING) {
    return common.ErrorSeverity.WARNING;
  } else  if (severity == ErrorSeverity.INFO) {
    return common.ErrorSeverity.INFO;
  } else {
    return common.ErrorSeverity.NONE;
  }
}

/**
 * An implementation of [Source] based on an in-memory Dart string.
 */
class StringSource extends Source {
  final String _contents;
  final String fullName;
  final int modificationStamp;

  StringSource(this._contents, this.fullName)
      : modificationStamp = new DateTime.now().millisecondsSinceEpoch;

  @override
  bool operator==(Object object) {
    if (object is StringSource) {
      return object._contents == _contents && object.fullName == fullName;
    } else {
      return false;
    }
  }

  @override
  bool exists() => true;

  @override
  TimestampedData<String> get contents =>
      new TimestampedData<String>(modificationStamp, _contents);

  void getContentsToReceiver(Source_ContentReceiver receiver) =>
      receiver.accept(_contents, modificationStamp);

  @override
  String get encoding => 'UTF-8';

  @override
  String get shortName => fullName;

  @override
  UriKind get uriKind =>
      throw new UnsupportedError("StringSource doesn't support uriKind.");

  @override
  Uri get uri => new Uri(scheme: FileSource.FILE_SCHEME, path: fullName);

  @override
  int get hashCode => _contents.hashCode ^ fullName.hashCode;

  @override
  bool get isInSystemLibrary => false;

  @override
  Uri resolveRelativeUri(Uri relativeUri) {
    return resolveRelativeUriHelper(uri, relativeUri);
//    Uri result;
//    int index = fullName.lastIndexOf('/');
//    if (index == -1) {
//      result = new StringSource('', fullName + '/' + relativeUri.toString()).uri;
//    } else {
//      result = new StringSource(
//          '', fullName.substring(0, index + 1) + relativeUri.toString()).uri;
//    }
//    return result;
  }
}

/**
 * A [Source] implementation based of a file in the SDK.
 */
class SdkSource extends Source {
  final sdk.DartSdk _sdk;
  /**
   * The URI from which this source was originally derived.
   * (e.g. "dart:core")
   */
  final Uri uri;
  /**
   * The path correspoding to the uri (e.g. "core/core.dart").
   */
  final String fullName;

  SdkSource(this._sdk, this.uri, this.fullName) {
    print("= SdkSource: uri=${uri}, path=${fullName}");
  }

  @override
  bool operator==(Object object) {
    if (object is SdkSource) {
      return object.fullName == fullName;
    } else {
      return false;
    }
  }

  @override
  bool exists() => true;

  @override
  TimestampedData<String> get contents {
    print("> SdkSource.contents");
    String source = _sdk.getSourceForPath(fullName);
    print("= SdkSource.getSourceForPath(${fullName}):${source == null ? 'null' : source.length}");
    TimestampedData<String> result = (source == null)
        ? null
        : new TimestampedData<String>(modificationStamp, source);
    print("< SdkSource.contents: ${result == null ? 'null' : result.data.length}");
    return result;
  }

  void getContentsToReceiver(Source_ContentReceiver receiver) {
    final cnt = contents;

    if (cnt != null) {
      receiver.accept(cnt.data, cnt.modificationTime);
    } else {
      // TODO(devoncarew): Error type seems wrong.
      throw new UnimplementedError('getContentsToReceiver');
    }
  }

  @override
  String get encoding => 'UTF-8';

  @override
  String get shortName => basename(fullName);

  @override
  UriKind get uriKind => UriKind.DART_URI;

  @override
  int get hashCode => fullName.hashCode;

  @override
  bool get isInSystemLibrary => true;

  @override
  Uri resolveRelativeUri(Uri relativeUri) {
    return resolveRelativeUriHelper(uri, relativeUri);
//    Uri result = new Uri(scheme: DartUriResolver.DART_SCHEME, path: '${dirname(fullName)}/${relativeUri.path}');
//    print("= SdkSource.resolveRelativeUri(${relativeUri}) = ${result} (fullName=${fullName})");
//    return result;
  }

  @override
  int get modificationStamp => 0;

  @override
  String toString() => "SdkSource(uri=${uri}, fullName=${fullName})";
}

/**
 * A [Source] implementation based on workspace uuids.
 */
class FileSource extends Source {
  static final FILE_SCHEME = "file";
  final ProjectContext context;
  final String uuid;

  int modificationStamp;
  bool _exists = true;
  String _strContents;

  FileSource(this.context, this.uuid) {
    assert(uuid != null);
    touchFile();
  }

  @override
  bool operator==(Object object) {
    return object is FileSource ? object.uuid == uuid : false;
  }

  @override
  bool exists() => _exists;

  @override
  TimestampedData<String> get contents {
    return new TimestampedData(modificationStamp, _strContents);
  }

  void getContentsToReceiver(Source_ContentReceiver receiver) {
    TimestampedData cnts = contents;
    receiver.accept(cnts.data, cnts.modificationTime);
  }

  @override
  String get encoding => 'UTF-8';

  @override
  String get shortName => basename(uuid);

  @override
  String get fullName {
    int index = uuid.indexOf('/');
    return index == -1 ? uuid : uuid.substring(index + 1);
  }

  @override
  UriKind get uriKind => UriKind.FILE_URI;

  @override
  Uri get uri => new Uri(scheme: FILE_SCHEME, path: uuid);

  @override
  int get hashCode => fullName.hashCode;

  @override
  bool get isInSystemLibrary => false;

  @override
  Uri resolveRelativeUri(Uri relativeUri) {
    return resolveRelativeUriHelper(uri, relativeUri);
//    Uri sourceUri = uri.resolveUri(relativeUri);
//    Uri result = context.getSource(sourceUri.path.substring(1)).uri;
//    print("= FileSource.resolveRelativeUri(${relativeUri}) = ${result} (fullName=${fullName})");
//    return result;
  }

  void setContents(String newContents) {
    _strContents = newContents;
    touchFile();
  }

  void touchFile() {
    modificationStamp = new DateTime.now().millisecondsSinceEpoch;
  }

  @override
  String toString() => uuid;
}

/**
 * [UriResolver] implementation for the "dart" URI scheme.
 */
class CustomDartUriResolver extends DartUriResolver {
  CustomDartUriResolver(DartSdk sdk) : super(sdk);

  /**
   * Return the source representing the SDK source file with the given `dart:`
   * [uri], or `null` if the given URI does not denote a file in the SDK.
   *
   * Notes:
   * * The scheme is expected to be "dart:".
   * * The path is formed of the library name (e.g. "core") optionally followed
   *   by a "/" and the path of the source file in the library (e.g. "core.dart",
   *   "bool.dart").
   * * This methods ends up calling [ChromeDartSdk.mapDartUri].
   */
  @override
  Source resolveAbsolute(Uri uri) {
    print("> CustomDartUriResolver.resolveAbsolute(${uri})");
    Source result = super.resolveAbsolute(uri);
    print("< CustomDartUriResolver.resolveAbsolute(${uri}): ${result == null ? 'null' : result.uri}");
    return result;
  }
}

/**
 * [UriResolver] implementation for the "file" URI scheme.
 */
class FileUriResolver extends UriResolver {
  static String FILE_SCHEME = "file";

  static bool isFileUri(Uri uri) => uri.scheme == FILE_SCHEME;

  final ProjectContext context;

  FileUriResolver(this.context);

  @override
  Source resolveAbsolute(Uri uri) {
    print("> FileUriResolver.resolveAbsolute(${uri})");
    Source result;
    if (!isFileUri(uri)) {
      result = null;
    } else {
      result = context.getSource(uri.path);
    }
    print("< FileUriResolver.resolveAbsolute(${uri}): ${result == null ? 'null' : result.uri}");
    return result;
  }
}

/**
 * [UriResolver] implementation for the "package" URI scheme.
 */
class PackageUriResolver extends UriResolver {
  static String PACKAGE_SCHEME = "package";

  static bool isPackageUri(Uri uri) => uri.scheme == PACKAGE_SCHEME;

  final ProjectContext context;

  PackageUriResolver(this.context);

  /**
   * Resolve the given absolute URI. Return a [Source] representing the file to
   * which it was resolved, whether or not the resulting source exists,
   * or `null` if it could not be resolved because the URI is invalid.
   */
  @override
  Source resolveAbsolute(Uri uri) {
    print("> PackageUriResolver.resolveAbsolute(${uri})");
    Source result;
    if (!isPackageUri(uri)) {
      result = null;
    } else {
      result = context.getSource(uri.toString());
    }
    print("< PackageUriResolver.resolveAbsolute(${uri}): ${result == null ? 'null' : result.uri}");
    return result;
  }
}

class SimpleAnalysisErrorListener implements AnalysisErrorListener {
  bool foundError = false;

  SimpleAnalysisErrorListener();

  @override
  void onError(AnalysisError error) {
    foundError = true;
  }
}

String basename(String str) {
  int index = str.lastIndexOf('/');
  return index == -1 ? str : str.substring(index + 1);
}

String dirname(String str) {
  int index = str.lastIndexOf('/');
  return index == -1 ? '' : str.substring(0, index);
}

/**
 * Note: this code is mostly a copy-paste of
 * `FileBasedSource.resolveRelativeUri` in the
 * `package:analyzer/source_io.dart` file. We cannot re-use the
 * implementation because we cannot use `dart:io`.
 */
Uri resolveRelativeUriHelper(Uri uri, Uri containedUri) {
  print("> resolveRelativeUriHelper(${uri}, ${containedUri})");
  Uri baseUri = uri;
  bool isOpaque = uri.isAbsolute && !uri.path.startsWith('/');
  if (isOpaque) {
    String scheme = uri.scheme;
    String part = uri.path;
    if (scheme == DartUriResolver.DART_SCHEME && part.indexOf('/') < 0) {
      part = "${part}/${part}.dart";
    }
    baseUri = parseUriWithException("${scheme}:/${part}");
  }
  Uri result = baseUri.resolveUri(containedUri);
  if (isOpaque) {
    result = parseUriWithException("${result.scheme}:${result.path.substring(1)}");
  }
  print("< resolveRelativeUriHelper(${uri}, ${containedUri}): ${result}");
  return result;
}

/**
 * Note: this code is mostly a copy-paste of the function with
 * the same name in `package:analyzer/generated/java_core.dart`.
 */
Uri parseUriWithException(String str) {
  Uri uri = Uri.parse(str);
  if (uri.path.isEmpty) {
    throw new URISyntaxException();
  }
  return uri;
}

class URISyntaxException implements Exception {
  String toString() => "URISyntaxException";
}
