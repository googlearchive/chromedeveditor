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
import 'package:path/path.dart' as path;

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

  // TODO: move over to using this factory method - it will share SDK contexts.
  //AnalysisContext context = AnalysisEngine.instance.createAnalysisContext();
  AnalysisContext context = new AnalysisContextImpl();

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
      m[uuid] = errors.map((e) => e.toMap());
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
    // TODO: this will also need a dart: uri resolver
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

  AnalysisContext context;

  Map<String, FileSource> _sources = {};

  ProjectContext(this.sdk, this.id){
    // TODO: move over to using this factory method - it will share SDK contexts.
    //AnalysisContext context = AnalysisEngine.instance.createAnalysisContext();
    context = new AnalysisContextImpl();

    // TODO: add a package: uri resolver
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
        _sources[uuid].touchFile();
      } else {
        _sources[uuid] = new FileSource(this, uuid);
      }

      changeSet.changedSource(_sources[uuid]);
    }

    // deleted
    for (String uuid in deletedUuids) {
      if (_sources[uuid] != null) {
        _sources[uuid]._exists = false;
        changeSet.removedSource(_sources.remove(uuid));
      }
    }

    context.applyChanges(changeSet);

    Completer<AnalysisResultUuid> completer = new Completer();
    _processChanges(completer, new AnalysisResultUuid());
    return completer.future;
  }

  // Not sure there's anything to do here -
  void dispose() { }

  FileSource getSource(String uuid) {
    //if (_sources.containsKey(uuid)) {
      return _sources[uuid];
    //} else {
    //  return new PhantomFileSource(this, uuid);
    //}
  }

  void _processChanges(Completer<AnalysisResultUuid> completer,
      AnalysisResultUuid analysisResult) {
    AnalysisResult result = context.performAnalysisTask();
    List<ChangeNotice> notices = result.changeNotices;

    if (notices == null) {
      print('notices == null');
      completer.complete(analysisResult);
    } else {
      print('${notices.length} notices');
      for (ChangeNotice notice in notices) {
        if (notice.source is FileSource) {
          FileSource source = notice.source;
          print(source);

          // TODO: record the errors
          analysisResult.addErrors(source.uuid, []);
        }
      }

      _processChanges(completer, analysisResult);
    }
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

  String get shortName => path.basename(fullName);

  UriKind get uriKind => UriKind.DART_URI;

  int get hashCode => fullName.hashCode;

  bool get isInSystemLibrary => true;

  Source resolveRelative(Uri relativeUri) {
    return new SdkSource(_sdk, '${path.dirname(fullName)}/${relativeUri.path}');
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

  TimestampedData<String> get contents =>
      new TimestampedData(modificationStamp, _strContents);

  void getContentsToReceiver(Source_ContentReceiver receiver) {
    TimestampedData cnts = contents;
    receiver.accept(cnts.data, cnts.modificationTime);
  }

  String get encoding => 'UTF-8';

  String get shortName {
    int index = uuid.lastIndexOf('/');
    return index == -1 ? uuid : uuid.substring(index + 1);
  }

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

    return context.getSource(sourceUri.path);
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

class PhantomFileSource extends FileSource {
  PhantomFileSource(ProjectContext context, String uuid) : super(context, uuid) {
    _exists = false;
  }

  // TODO:
  TimestampedData<String> get contents =>
      new TimestampedData(modificationStamp, _strContents);

  // TODO:
  void getContentsToReceiver(Source_ContentReceiver receiver) {
    TimestampedData cnts = contents;
    receiver.accept(cnts.data, cnts.modificationTime);
  }
}

class FileUriResolver extends UriResolver {
  final ProjectContext context;

  FileUriResolver(this.context);

  Source fromEncoding(UriKind kind, Uri uri) => context.getSource(uri.path);

  Source resolveAbsolute(Uri uri) => context.getSource(uri.path);
}

class SimpleAnalysisErrorListener implements AnalysisErrorListener {
  bool foundError = false;

  SimpleAnalysisErrorListener();

  void onError(AnalysisError error) {
    foundError = true;
  }
}
