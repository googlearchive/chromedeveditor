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
export 'package:analyzer/src/generated/error.dart';
export 'package:analyzer/src/generated/source.dart' show LineInfo_Location;

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
Future<AnalyzerResult> analyzeString(ChromeDartSdk sdk, String contents,
    {bool performResolution: true}) {
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

  if (performResolution) {
    context.computeErrors(source);
    // Generally, we won't be resolving string fragments.
    unit = context.resolveCompilationUnit(source, context.getLibraryElement(source));
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
  Map<String, List<common.AnalysisError>> _errorMap = {};

  AnalysisResultUuid();

  void addErrors(String uuid, List<common.AnalysisError> errors) {
    _errorMap[uuid] = errors;
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

  sdk.DartSdk _sdk;
  LibraryMap _libraryMap;

  ChromeDartSdk._(this._sdk): context = new AnalysisContextImpl() {
    context.sourceFactory = new SourceFactory([]);
  }

  Source fromEncoding(UriKind kind, Uri uri) {
    // TODO:
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

/**
 * A wrapper around an analysis context. There is a one-to-one mapping between
 * projects, on the DOM side, and analysis contexts.
 */
class ProjectContext {
  // The id for the project this context is associated with.
  final String id;
  final ChromeDartSdk sdk;
  final common.ContentsProvider provider;

  AnalysisContext context;

  Map<String, FileSource> _sources = {};

  ProjectContext(this.id, this.sdk, this.provider) {
    context = AnalysisEngine.instance.createAnalysisContext();

    // TODO: Add a package: uri resolver. (PackageUriResolver)
    context.sourceFactory = new SourceFactory(
        [new DartUriResolver(sdk), new FileUriResolver(this)]);
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
        _sources[uuid]._exists = false;
        _sources[uuid].setContents(null);
        changeSet.removedSource(_sources.remove(uuid));
      }
    }

    context.applyChanges(changeSet);

    Completer<AnalysisResultUuid> completer = new Completer();

    _populateSources().then((_) {
      _processChanges(completer, new AnalysisResultUuid());
    }).catchError((e) {
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

      if (notices == null) {
        completer.complete(analysisResult);
      } else {
        for (ChangeNotice notice in notices) {
          if (notice.source is! FileSource) continue;

          FileSource source = notice.source;
          analysisResult.addErrors(
              source.uuid, _convertErrors(notice, notice.errors));
        }

        _processChanges(completer, analysisResult);
      }
    } catch (e, st) {
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
        Future f = provider.getFileContents(uuid).then((String str) {
          source.setContents(str);
        });
        futures.add(f);
      }
    });

    return Future.wait(futures);
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
      return object._contents == _contents && object.fullName == fullName;
    } else {
      return false;
    }
  }

  bool exists() => true;

  TimestampedData<String> get contents =>
      new TimestampedData<String>(modificationStamp, _contents);

  void getContentsToReceiver(Source_ContentReceiver receiver) =>
      receiver.accept(_contents, modificationStamp);

  String get encoding => 'UTF-8';

  String get shortName => fullName;

  UriKind get uriKind => throw new UnsupportedError(
      "StringSource doesn't support uriKind.");

  int get hashCode => _contents.hashCode ^ fullName.hashCode;

  bool get isInSystemLibrary => false;

  Source resolveRelative(Uri relativeUri) => throw new UnsupportedError(
      "StringSource doesn't support resolveRelative.");
}

/**
 * A [Source] implementation based of a file in the SDK.
 */
class SdkSource extends Source {
  final sdk.DartSdk _sdk;
  final String fullName;

  SdkSource(this._sdk, this.fullName);

  bool operator==(Object object) {
    if (object is SdkSource) {
      return object.fullName == fullName;
    } else {
      return false;
    }
  }

  bool exists() => true;

  TimestampedData<String> get contents {
    String source = _sdk.getSourceForPath(fullName);
    return source != null ?
        new TimestampedData<String>(modificationStamp, source) : null;
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

  String get encoding => 'UTF-8';

  String get shortName => basename(fullName);

  UriKind get uriKind => UriKind.DART_URI;

  int get hashCode => fullName.hashCode;

  bool get isInSystemLibrary => true;

  Source resolveRelative(Uri relativeUri) {
    return new SdkSource(_sdk, '${dirname(fullName)}/${relativeUri.path}');
  }

  int get modificationStamp => 0;

  String toString() => fullName;
}

/**
 * A [Source] implementation based on workspace uuids.
 */
class FileSource extends Source {
  final ProjectContext context;
  final String uuid;

  int modificationStamp;
  bool _exists = true;
  String _strContents;

  FileSource(this.context, this.uuid) {
    touchFile();
  }

  bool operator==(Object object) {
    return object is FileSource ? object.uuid == uuid : false;
  }

  bool exists() => _exists;

  TimestampedData<String> get contents {
    return new TimestampedData(modificationStamp, _strContents);
  }

  void getContentsToReceiver(Source_ContentReceiver receiver) {
    TimestampedData cnts = contents;
    receiver.accept(cnts.data, cnts.modificationTime);
  }

  String get encoding => 'UTF-8';

  String get shortName => basename(uuid);

  String get fullName {
    int index = uuid.indexOf('/');
    return index == -1 ? uuid : uuid.substring(index + 1);
  }

  UriKind get uriKind => UriKind.FILE_URI;

  int get hashCode => fullName.hashCode;

  bool get isInSystemLibrary => false;

  Source resolveRelative(Uri relativeUri) {
    Uri thisUri = new Uri(scheme: 'file', path: uuid);
    Uri sourceUri = thisUri.resolveUri(relativeUri);

    return context.getSource(sourceUri.path.substring(1));
  }

  void setContents(String newContents) {
    _strContents = newContents;
    touchFile();
  }

  void touchFile() {
    modificationStamp = new DateTime.now().millisecondsSinceEpoch;
  }

  String toString() => uuid;
}

class FileUriResolver extends UriResolver {
  static String FILE_SCHEME = "file";

  static bool isFileUri(Uri uri) => uri.scheme == FILE_SCHEME;

  final ProjectContext context;

  FileUriResolver(this.context);

  Source fromEncoding(UriKind kind, Uri uri) {
    if (kind == UriKind.FILE_URI) {
      return context.getSource(uri.path);
    } else {
      return null;
    }
  }

  Source resolveAbsolute(Uri uri) {
    if (!isFileUri(uri)) {
      return null;
    } else {
      return context.getSource(uri.path);
    }
  }
}

class PackageUriResolver extends UriResolver {
  static String PACKAGE_SCHEME = "package";

  static bool isPackageUri(Uri uri) => uri.scheme == PACKAGE_SCHEME;

  final ProjectContext context;

  PackageUriResolver(this.context);

  Source fromEncoding(UriKind kind, Uri uri) {
    if (kind == UriKind.PACKAGE_URI) {
      return context.getSource(uri.path);
    } else {
      return null;
    }
  }

  Source resolveAbsolute(Uri uri) {
    if (!isPackageUri(uri)) {
      return null;
    } else {
      // TODO: Use the services content provider.
      return context.getSource(uri.path);
    }
  }
}

class SimpleAnalysisErrorListener implements AnalysisErrorListener {
  bool foundError = false;

  SimpleAnalysisErrorListener();

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
