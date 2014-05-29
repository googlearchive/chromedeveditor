// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * An embedded http server. This is used when launching web apps from Spark.
 */
library spark.server;

import 'dart:async';
import 'dart:convert';

import 'package:intl/intl.dart' as intl;
import 'package:logging/logging.dart';
import 'package:mime/mime.dart' as mime;

import 'tcp.dart' as tcp;

const int DEFAULT_HTTP_PORT = 80;

final intl.DateFormat RFC_1123_DATE_FORMAT =
    new intl.Intl().date('EEE, dd MMM yyyy HH:mm:ss z');

final Logger _logger = new Logger('spark.server');

// TODO(devoncarew): support HEAD requests

/**
 * An embedded http server.
 *
 * ## Usage:
 *
 *     PicoServer.createServer();
 *     addServlet(fooServlet);
 *     addServlet(barServlet);
 *     dispose();
 */
class PicoServer {
  tcp.TcpServer _server;
  List<PicoServlet> _servlets = [];

  /**
   * Create an instance of an http server, bound to the given port. If [port] is
   * `0`, this will bind to any available port.
   */
  static Future<PicoServer> createServer([int port = 0]) {
    return tcp.TcpServer.createServerSocket(port).then((tcp.TcpServer server) {
      return new PicoServer._(server);
    });
  }

  PicoServer._(this._server) {
    _server.onAccept.listen(_serveClient);
  }

  int get port => _server.port;

  void addServlet(PicoServlet servlet) => _servlets.add(servlet);

  Future<tcp.SocketInfo> getInfo() => _server.getInfo();

  Future dispose() {
    return _server.dispose();
  }

  void _serveClient(tcp.TcpClient client) {
    HttpRequest._parse(client).then((HttpRequest request) {
      _logger.info('<== ${request}');

      for (PicoServlet servlet in _servlets) {
        if (servlet.canServe(request)) {
          _serve(servlet, client, request);
          return;
        }
      }

      HttpResponse response = new HttpResponse.notFound();
      _logger.info('==> ${response}');
      response._send(client).then((_) {
        client.dispose();
      });
    }).catchError((e) {
      HttpResponse response = new HttpResponse.badRequest();
      _logger.info('==> ${response}');
      response._send(client).then((_) {
        client.dispose();
      });
    });
  }

  void _serve(PicoServlet servlet, tcp.TcpClient client, HttpRequest request) {
    servlet.serve(request).then((HttpResponse response) {
      _logger.info('==> ${response}');
      response._send(client).then((_) {
        // TODO: Try and re-use the connection.
        client.dispose();
      });
    });
  }
}

/**
 * One or more [PicoServlet]s can be added to a [PicoServer] in order to handle
 * http requests.
 */
abstract class PicoServlet {
  /**
   * Returns whether this servlet can serve the given [HttpRequest].
   */
  bool canServe(HttpRequest request) => true;

  /**
   * Handle the given [HttpRequest], and return a Future with a [HttpResponse].
   */
  Future<HttpResponse> serve(HttpRequest request);
}

/**
 * An object that contains the content of and information of an HTTP request.
 */
class HttpRequest {
  static final HEADER_END = [13, 10, 13, 10];

  static Future<HttpRequest> _parse(tcp.TcpClient client) {
    Completer<HttpRequest> completer = new Completer();

    List<int> collectedData = [];
    int statePos = 0;

    StreamSubscription sub;

    // collect all bytes until we receieve \r\n\r\n
    sub = client.stream.listen((List<int> data) {
      int i = 0;

      for (; i < data.length; i++) {
        collectedData.add(data[i]);

        if (data[i] == HEADER_END[statePos]) {
          statePos++;
        } else {
          statePos = 0;
        }

        if (statePos == HEADER_END.length){
          sub.cancel();

          List remainingData = (i + 1 < data.length ? data.sublist(i + 1) : []);
          HttpRequest request = _parseHeader(client, collectedData, remainingData);

          if (request != null) {
            completer.complete(request);
          } else {
            completer.completeError(new HttpException('error parsing request'));
          }

          break;
        }
      }
    }, onError: (e) {
      completer.completeError(e);
    });

    return completer.future;
  }

  static HttpRequest _parseHeader(tcp.TcpClient client,
      List<int> headerData, List<int> remainingData) {
    String header = new String.fromCharCodes(headerData);
    List<String> lines = header.split('\n').map((s) => s.trim()).toList();

    if (lines.isEmpty) return null;

    String start = lines.first;

    if (start.isEmpty) return null;

    // GET /index.html HTTP/1.1
    String method;
    Uri path;
    String version = '1.1';

    List strs = start.split(' ');

    if (strs.length > 2) {
      method = strs[0];
      path = new Uri(path: strs[1]);
      version = _parseVersion(strs[2]);
    }

    _HttpHeaders headers = new _HttpHeaders(version);

    for (String line in lines.skip(1)) {
      if (line.isEmpty) continue;

      int index = line.indexOf(':');

      if (index == -1) {
        headers._add(line, '');
      } else {
        headers._add(line.substring(0, index), line.substring(index + 1).trim());
      }
    }

    return new HttpRequest._(method: method, uri: path, headers: headers);
  }

  /// 'HTTP/1.1' ==> '1.1'
  static String _parseVersion(String ver) {
    int index = ver.indexOf('/');

    return index == -1 ? '1.1' : ver.substring(index + 1);
  }

  /**
   * The content length of the request body (read-only).
   *
   * If the size of the request body is not known in advance, this value is -1.
   */
  int get contentLength => headers.contentLength;

  /**
   * The method, such as 'GET' or 'POST', for the request (read-only).
   */
  final String method;

  /**
   * The URI for the request (read-only).
   *
   * This provides access to the path, query string, and fragment identifier for
   * the request.
   */
  final Uri uri;

  /**
   * The request headers (read-only).
   */
  final HttpHeaders headers;

  /**
   * The HTTP protocol version used in the request, either "1.0" or "1.1"
   * (read-only).
   */
  String get protocolVersion => (headers as _HttpHeaders).protocolVersion;

  HttpRequest._({this.method, this.uri, this.headers});

  String toString() => '${method} ${uri} ${protocolVersion}';
}

/**
 * An [HttpResponse] represents the headers and data to be returned to
 * a client in response to an HTTP request.
 */
class HttpResponse {
  /**
   * Gets and sets the content length of the response. If the size of
   * the response is not known in advance set the content length to
   * -1 - which is also the default if not set.
   */
  int get contentLength => headers.contentLength;

  /**
   * Gets and sets the status code. Any integer value is accepted. For
   * the official HTTP status codes use the fields from
   * [HttpStatus]. If no status code is explicitly set the default
   * value [HttpStatus.OK] is used.
   */
  int statusCode;

  /**
   * Gets and sets the reason phrase. If no reason phrase is explicitly
   * set a default reason phrase is provided.
   */
  String reasonPhrase;

  List<int> _data;
  Stream<List<int>> _streamData;

  /**
   * The response headers.
   */
  HttpHeaders headers = new _HttpHeaders("1.1");

  HttpResponse({this.statusCode, this.reasonPhrase}) {
    headers.add(HttpHeaders.SERVER, 'Spark');
  }

  HttpResponse.ok(): this(statusCode: HttpStatus.OK);
  HttpResponse.notFound(): this(statusCode: HttpStatus.NOT_FOUND);
  HttpResponse.badRequest(): this(statusCode: HttpStatus.BAD_REQUEST);

  void setContent(String str) {
    // TODO(devoncarew): set the charset to UTF-8

    setContentBytes(UTF8.encode(str));
  }

  void setContentBytes(List<int> data) {
    _data = data;
    headers.contentLength = _data.length;
  }

  void setContentStream(Stream<List<int>> streamData) {
    _streamData = streamData;
    headers.contentLength = -1;
  }

  /**
   * Set the content type for this response given a file path. This auto-detects
   * based on the file extension.
   */
  void setContentTypeFrom(String path) {
    headers.contentType = mime.lookupMimeType(path);
  }

  Future _send(tcp.TcpClient client) {
    final String eol = '\r\n';

    BytesBuilder builder = new BytesBuilder();

    // send http/1.1 ...
    builder.add('HTTP/1.1 ${statusCode} ${_calcPhrase}${eol}'.codeUnits);

    // send headers
    (headers as _HttpHeaders)._write(builder);

    builder.add(eol.codeUnits);

    // send data
    if (_data != null) {
      builder.add(_data);
      client.write(builder.toBytes());
      return new Future.value();
    } else if (_streamData != null) {
      client.write(builder.toBytes());
      Completer completer = new Completer();

      _streamData.listen((List<int> bytes) {
        client.write(bytes);
      }, onDone: () => completer.complete());

      return completer.future;
    } else {
      client.write(builder.toBytes());
      return new Future.value();
    }
  }

  String get _calcPhrase {
    if (reasonPhrase == null) {
      return HttpStatus.getReasonPhrase(statusCode);
    } else {
      return reasonPhrase;
    }
  }

  String toString() => 'HTTP/1.1 ${statusCode} ${_calcPhrase}';
}

/**
 * HTTP status codes.
 */
abstract class HttpStatus {
  static const int CONTINUE = 100;
  static const int SWITCHING_PROTOCOLS = 101;
  static const int OK = 200;
  static const int CREATED = 201;
  static const int ACCEPTED = 202;
  static const int NON_AUTHORITATIVE_INFORMATION = 203;
  static const int NO_CONTENT = 204;
  static const int RESET_CONTENT = 205;
  static const int PARTIAL_CONTENT = 206;
  static const int MULTIPLE_CHOICES = 300;
  static const int MOVED_PERMANENTLY = 301;
  static const int FOUND = 302;
  static const int MOVED_TEMPORARILY = 302; // Common alias for FOUND.
  static const int SEE_OTHER = 303;
  static const int NOT_MODIFIED = 304;
  static const int USE_PROXY = 305;
  static const int TEMPORARY_REDIRECT = 307;
  static const int BAD_REQUEST = 400;
  static const int UNAUTHORIZED = 401;
  static const int PAYMENT_REQUIRED = 402;
  static const int FORBIDDEN = 403;
  static const int NOT_FOUND = 404;
  static const int METHOD_NOT_ALLOWED = 405;
  static const int NOT_ACCEPTABLE = 406;
  static const int PROXY_AUTHENTICATION_REQUIRED = 407;
  static const int REQUEST_TIMEOUT = 408;
  static const int CONFLICT = 409;
  static const int GONE = 410;
  static const int LENGTH_REQUIRED = 411;
  static const int PRECONDITION_FAILED = 412;
  static const int REQUEST_ENTITY_TOO_LARGE = 413;
  static const int REQUEST_URI_TOO_LONG = 414;
  static const int UNSUPPORTED_MEDIA_TYPE = 415;
  static const int REQUESTED_RANGE_NOT_SATISFIABLE = 416;
  static const int EXPECTATION_FAILED = 417;
  static const int INTERNAL_SERVER_ERROR = 500;
  static const int NOT_IMPLEMENTED = 501;
  static const int BAD_GATEWAY = 502;
  static const int SERVICE_UNAVAILABLE = 503;
  static const int GATEWAY_TIMEOUT = 504;
  static const int HTTP_VERSION_NOT_SUPPORTED = 505;
  // Client generated status code.
  static const int NETWORK_CONNECT_TIMEOUT_ERROR = 599;

  static String getReasonPhrase(int statusCode) {
    switch (statusCode) {
      case HttpStatus.CONTINUE: return "Continue";
      case HttpStatus.SWITCHING_PROTOCOLS: return "Switching Protocols";
      case HttpStatus.OK: return "OK";
      case HttpStatus.CREATED: return "Created";
      case HttpStatus.ACCEPTED: return "Accepted";
      case HttpStatus.NON_AUTHORITATIVE_INFORMATION:
        return "Non-Authoritative Information";
      case HttpStatus.NO_CONTENT: return "No Content";
      case HttpStatus.RESET_CONTENT: return "Reset Content";
      case HttpStatus.PARTIAL_CONTENT: return "Partial Content";
      case HttpStatus.MULTIPLE_CHOICES: return "Multiple Choices";
      case HttpStatus.MOVED_PERMANENTLY: return "Moved Permanently";
      case HttpStatus.FOUND: return "Found";
      case HttpStatus.SEE_OTHER: return "See Other";
      case HttpStatus.NOT_MODIFIED: return "Not Modified";
      case HttpStatus.USE_PROXY: return "Use Proxy";
      case HttpStatus.TEMPORARY_REDIRECT: return "Temporary Redirect";
      case HttpStatus.BAD_REQUEST: return "Bad Request";
      case HttpStatus.UNAUTHORIZED: return "Unauthorized";
      case HttpStatus.PAYMENT_REQUIRED: return "Payment Required";
      case HttpStatus.FORBIDDEN: return "Forbidden";
      case HttpStatus.NOT_FOUND: return "Not Found";
      case HttpStatus.METHOD_NOT_ALLOWED: return "Method Not Allowed";
      case HttpStatus.NOT_ACCEPTABLE: return "Not Acceptable";
      case HttpStatus.PROXY_AUTHENTICATION_REQUIRED:
        return "Proxy Authentication Required";
      case HttpStatus.REQUEST_TIMEOUT: return "Request Time-out";
      case HttpStatus.CONFLICT: return "Conflict";
      case HttpStatus.GONE: return "Gone";
      case HttpStatus.LENGTH_REQUIRED: return "Length Required";
      case HttpStatus.PRECONDITION_FAILED: return "Precondition Failed";
      case HttpStatus.REQUEST_ENTITY_TOO_LARGE:
        return "Request Entity Too Large";
      case HttpStatus.REQUEST_URI_TOO_LONG: return "Request-URI Too Large";
      case HttpStatus.UNSUPPORTED_MEDIA_TYPE: return "Unsupported Media Type";
      case HttpStatus.REQUESTED_RANGE_NOT_SATISFIABLE:
        return "Requested range not satisfiable";
      case HttpStatus.EXPECTATION_FAILED: return "Expectation Failed";
      case HttpStatus.INTERNAL_SERVER_ERROR: return "Internal Server Error";
      case HttpStatus.NOT_IMPLEMENTED: return "Not Implemented";
      case HttpStatus.BAD_GATEWAY: return "Bad Gateway";
      case HttpStatus.SERVICE_UNAVAILABLE: return "Service Unavailable";
      case HttpStatus.GATEWAY_TIMEOUT: return "Gateway Time-out";
      case HttpStatus.HTTP_VERSION_NOT_SUPPORTED:
        return "Http Version not supported";
      default: return "Status $statusCode";
    }
  }
}

/**
 * Access to the HTTP headers for requests and responses. In some
 * situations the headers will be immutable and the mutating methods
 * will then throw exceptions.
 *
 * For all operations on HTTP headers the header name is
 * case-insensitive.
 */
abstract class HttpHeaders {
  static const ACCEPT = "accept";
  static const ACCEPT_CHARSET = "accept-charset";
  static const ACCEPT_ENCODING = "accept-encoding";
  static const ACCEPT_LANGUAGE = "accept-language";
  static const ACCEPT_RANGES = "accept-ranges";
  static const AGE = "age";
  static const ALLOW = "allow";
  static const AUTHORIZATION = "authorization";
  static const CACHE_CONTROL = "cache-control";
  static const CONNECTION = "connection";
  static const CONTENT_ENCODING = "content-encoding";
  static const CONTENT_LANGUAGE = "content-language";
  static const CONTENT_LENGTH = "content-length";
  static const CONTENT_LOCATION = "content-location";
  static const CONTENT_MD5 = "content-md5";
  static const CONTENT_RANGE = "content-range";
  static const CONTENT_TYPE = "content-type";
  static const DATE = "date";
  static const ETAG = "etag";
  static const EXPECT = "expect";
  static const EXPIRES = "expires";
  static const FROM = "from";
  static const HOST = "host";
  static const IF_MATCH = "if-match";
  static const IF_MODIFIED_SINCE = "if-modified-since";
  static const IF_NONE_MATCH = "if-none-match";
  static const IF_RANGE = "if-range";
  static const IF_UNMODIFIED_SINCE = "if-unmodified-since";
  static const LAST_MODIFIED = "last-modified";
  static const LOCATION = "location";
  static const MAX_FORWARDS = "max-forwards";
  static const PRAGMA = "pragma";
  static const PROXY_AUTHENTICATE = "proxy-authenticate";
  static const PROXY_AUTHORIZATION = "proxy-authorization";
  static const RANGE = "range";
  static const REFERER = "referer";
  static const RETRY_AFTER = "retry-after";
  static const SERVER = "server";
  static const TE = "te";
  static const TRAILER = "trailer";
  static const TRANSFER_ENCODING = "transfer-encoding";
  static const UPGRADE = "upgrade";
  static const USER_AGENT = "user-agent";
  static const VARY = "vary";
  static const VIA = "via";
  static const WARNING = "warning";
  static const WWW_AUTHENTICATE = "www-authenticate";

  // Cookie headers from RFC 6265.
  static const COOKIE = "cookie";
  static const SET_COOKIE = "set-cookie";

  static const GENERAL_HEADERS = const [CACHE_CONTROL,
                                        CONNECTION,
                                        DATE,
                                        PRAGMA,
                                        TRAILER,
                                        TRANSFER_ENCODING,
                                        UPGRADE,
                                        VIA,
                                        WARNING];

  static const ENTITY_HEADERS = const [ALLOW,
                                       CONTENT_ENCODING,
                                       CONTENT_LANGUAGE,
                                       CONTENT_LENGTH,
                                       CONTENT_LOCATION,
                                       CONTENT_MD5,
                                       CONTENT_RANGE,
                                       CONTENT_TYPE,
                                       EXPIRES,
                                       LAST_MODIFIED];


  static const RESPONSE_HEADERS = const [ACCEPT_RANGES,
                                         AGE,
                                         ETAG,
                                         LOCATION,
                                         PROXY_AUTHENTICATE,
                                         RETRY_AFTER,
                                         SERVER,
                                         VARY,
                                         WWW_AUTHENTICATE];

  static const REQUEST_HEADERS = const [ACCEPT,
                                        ACCEPT_CHARSET,
                                        ACCEPT_ENCODING,
                                        ACCEPT_LANGUAGE,
                                        AUTHORIZATION,
                                        EXPECT,
                                        FROM,
                                        HOST,
                                        IF_MATCH,
                                        IF_MODIFIED_SINCE,
                                        IF_NONE_MATCH,
                                        IF_RANGE,
                                        IF_UNMODIFIED_SINCE,
                                        MAX_FORWARDS,
                                        PROXY_AUTHORIZATION,
                                        RANGE,
                                        REFERER,
                                        TE,
                                        USER_AGENT];

  /**
   * Returns the list of values for the header named [name]. If there
   * is no header with the provided name, [:null:] will be returned.
   */
  List<String> operator[](String name);

  /**
   * Convenience method for the value for a single valued header. If
   * there is no header with the provided name, [:null:] will be
   * returned. If the header has more than one value an exception is
   * thrown.
   */
  String value(String name);

  /**
   * Adds a header value. The header named [name] will have the value
   * [value] added to its list of values. Some headers are single
   * valued, and for these adding a value will replace the previous
   * value. If the value is of type DateTime a HTTP date format will be
   * applied. If the value is a [:List:] each element of the list will
   * be added separately. For all other types the default [:toString:]
   * method will be used.
   */
  void add(String name, Object value);

  /**
   * Sets a header. The header named [name] will have all its values
   * cleared before the value [value] is added as its value.
   */
  void set(String name, Object value);

  /**
   * Removes a specific value for a header name. Some headers have
   * system supplied values and for these the system supplied values
   * will still be added to the collection of values for the header.
   */
  void remove(String name, Object value);

  /**
   * Removes all values for the specified header name. Some headers
   * have system supplied values and for these the system supplied
   * values will still be added to the collection of values for the
   * header.
   */
  void removeAll(String name);

  /**
   * Enumerates the headers, applying the function [f] to each
   * header. The header name passed in [:name:] will be all lower
   * case.
   */
  void forEach(void f(String name, List<String> values));

  /**
   * Disables folding for the header named [name] when sending the HTTP
   * header. By default, multiple header values are folded into a
   * single header line by separating the values with commas. The
   * 'set-cookie' header has folding disabled by default.
   */
  void noFolding(String name);

  /**
   * Gets and sets the date. The value of this property will
   * reflect the 'date' header.
   */
  DateTime date;

  /**
   * Gets and sets the expiry date. The value of this property will
   * reflect the 'expires' header.
   */
  DateTime expires;

  /**
   * Gets and sets the "if-modified-since" date. The value of this property will
   * reflect the "if-modified-since" header.
   */
  DateTime ifModifiedSince;

  /**
   * Gets and sets the host part of the 'host' header for the
   * connection.
   */
  String host;

  /**
   * Gets and sets the port part of the 'host' header for the
   * connection.
   */
  int port;

  /**
   * Gets and sets the content type. Note that the content type in the header
   * will only be updated if this field is set directly. Mutating the returned
   * current value will have no effect.
   */
  String contentType;

  /**
   * Gets and sets the content length header value.
   */
  int contentLength;

  /**
   * Gets and sets the persistent connection header value.
   */
  bool persistentConnection;

  /**
   * Gets and sets the chunked transfer encoding header value.
   */
  bool chunkedTransferEncoding;
}

class HttpException implements Exception {
  final String message;
  final Uri uri;

  const HttpException(String this.message, {Uri this.uri});

  String toString() {
    var b = new StringBuffer();
    b.write('HttpException: ');
    b.write(message);
    if (uri != null) {
      b.write(', uri = $uri');
    }
    return b.toString();
  }
}

class _HttpHeaders implements HttpHeaders {
  _HttpHeaders(String this.protocolVersion)
      : _headers = new Map<String, List<String>>();

  List<String> operator[](String name) {
    name = name.toLowerCase();
    return _headers[name];
  }

  String value(String name) {
    name = name.toLowerCase();
    List<String> values = _headers[name];
    if (values == null) return null;
    if (values.length > 1) {
      throw new HttpException("More than one value for header $name");
    }
    return values[0];
  }

  void add(String name, value) {
    _checkMutable();
    if (value is List) {
      for (int i = 0; i < value.length; i++) {
        _add(name, value[i]);
      }
    } else {
      _add(name, value);
    }
  }

  void set(String name, Object value) {
    name = name.toLowerCase();
    _checkMutable();
    removeAll(name);
    add(name, value);
  }

  void remove(String name, Object value) {
    _checkMutable();
    name = name.toLowerCase();
    List<String> values = _headers[name];
    if (values != null) {
      int index = values.indexOf(value);
      if (index != -1) {
        values.removeRange(index, index + 1);
      }
      if (values.length == 0) _headers.remove(name);
    }
  }

  void removeAll(String name) {
    _checkMutable();
    name = name.toLowerCase();
    _headers.remove(name);
  }

  void forEach(void f(String name, List<String> values)) {
    _headers.forEach(f);
  }

  void noFolding(String name) {
    if (_noFoldingHeaders == null) _noFoldingHeaders = new List<String>();
    _noFoldingHeaders.add(name);
  }

  bool get persistentConnection {
    List<String> connection = _headers[HttpHeaders.CONNECTION];
    if (protocolVersion == "1.1") {
      if (connection == null) return true;
      return !connection.any((value) => value.toLowerCase() == "close");
    } else {
      if (connection == null) return false;
      return connection.any((value) => value.toLowerCase() == "keep-alive");
    }
  }

  void set persistentConnection(bool persistentConnection) {
    _checkMutable();
    // Determine the value of the "Connection" header.
    remove(HttpHeaders.CONNECTION, "close");
    remove(HttpHeaders.CONNECTION, "keep-alive");
    if (protocolVersion == "1.1" && !persistentConnection) {
      add(HttpHeaders.CONNECTION, "close");
    } else if (protocolVersion == "1.0" && persistentConnection) {
      add(HttpHeaders.CONNECTION, "keep-alive");
    }
  }

  int get contentLength => _contentLength;

  void set contentLength(int contentLength) {
    _checkMutable();
    _contentLength = contentLength;
    if (_contentLength >= 0) {
      _set(HttpHeaders.CONTENT_LENGTH, contentLength.toString());
    } else {
      removeAll(HttpHeaders.CONTENT_LENGTH);
    }
  }

  bool get chunkedTransferEncoding => _chunkedTransferEncoding;

  void set chunkedTransferEncoding(bool chunkedTransferEncoding) {
    _checkMutable();
    _chunkedTransferEncoding = chunkedTransferEncoding;
    List<String> values = _headers[HttpHeaders.TRANSFER_ENCODING];
    if ((values == null || values[values.length - 1] != "chunked") &&
        chunkedTransferEncoding) {
      // Headers does not specify chunked encoding - add it if set.
        _addValue(HttpHeaders.TRANSFER_ENCODING, "chunked");
    } else if (!chunkedTransferEncoding) {
      // Headers does specify chunked encoding - remove it if not set.
      remove(HttpHeaders.TRANSFER_ENCODING, "chunked");
    }
  }

  String get host => _host;

  void set host(String host) {
    _checkMutable();
    _host = host;
    _updateHostHeader();
  }

  int get port => _port;

  void set port(int port) {
    _checkMutable();
    _port = port;
    _updateHostHeader();
  }

  DateTime get ifModifiedSince {
    List<String> values = _headers[HttpHeaders.IF_MODIFIED_SINCE];
    if (values != null) {
      try {
        return RFC_1123_DATE_FORMAT.parseUTC(values[0]);
      } on Exception catch (e) {
        return null;
      }
    }
    return null;
  }

  void set ifModifiedSince(DateTime ifModifiedSince) {
    _checkMutable();
    // Format "ifModifiedSince" header with date in Greenwich Mean Time (GMT).
    String formatted = RFC_1123_DATE_FORMAT.format(ifModifiedSince.toUtc());
    _set(HttpHeaders.IF_MODIFIED_SINCE, formatted);
  }

  DateTime get date {
    List<String> values = _headers[HttpHeaders.DATE];
    if (values != null) {
      try {
        return RFC_1123_DATE_FORMAT.parseUTC(values[0]);
      } on Exception catch (e) {
        return null;
      }
    }
    return null;
  }

  void set date(DateTime date) {
    _checkMutable();
    // Format "DateTime" header with date in Greenwich Mean Time (GMT).
    String formatted = RFC_1123_DATE_FORMAT.format(date.toUtc());
    _set("date", formatted);
  }

  DateTime get expires {
    List<String> values = _headers[HttpHeaders.EXPIRES];
    if (values != null) {
      try {
        return RFC_1123_DATE_FORMAT.parseUTC(values[0]);
      } on Exception catch (e) {
        return null;
      }
    }
    return null;
  }

  void set expires(DateTime expires) {
    _checkMutable();
    // Format "Expires" header with date in Greenwich Mean Time (GMT).
    String formatted = RFC_1123_DATE_FORMAT.format(expires.toUtc());
    _set(HttpHeaders.EXPIRES, formatted);
  }

  String get contentType {
    var values = _headers["content-type"];
    if (values != null) {
      return values[0];
    } else {
      return null;
    }
  }

  void set contentType(String contentType) {
    _checkMutable();
    _set(HttpHeaders.CONTENT_TYPE, contentType);
  }

  void _add(String name, value) {
    var lowerCaseName = name.toLowerCase();
    if (lowerCaseName == HttpHeaders.CONTENT_LENGTH) {
      if (value is int) {
        contentLength = value;
      } else if (value is String) {
        contentLength = int.parse(value);
      } else {
        throw new HttpException("Unexpected type for header named $name");
      }
    } else if (lowerCaseName == HttpHeaders.TRANSFER_ENCODING) {
      if (value == "chunked") {
        chunkedTransferEncoding = true;
      } else {
        _addValue(lowerCaseName, value);
      }
    } else if (lowerCaseName == HttpHeaders.DATE) {
      if (value is DateTime) {
        date = value;
      } else if (value is String) {
        _set(HttpHeaders.DATE, value);
      } else {
        throw new HttpException("Unexpected type for header named $name");
      }
    } else if (lowerCaseName == HttpHeaders.EXPIRES) {
      if (value is DateTime) {
        expires = value;
      } else if (value is String) {
        _set(HttpHeaders.EXPIRES, value);
      } else {
        throw new HttpException("Unexpected type for header named $name");
      }
    } else if (lowerCaseName == HttpHeaders.IF_MODIFIED_SINCE) {
      if (value is DateTime) {
        ifModifiedSince = value;
      } else if (value is String) {
        _set(HttpHeaders.IF_MODIFIED_SINCE, value);
      } else {
        throw new HttpException("Unexpected type for header named $name");
      }
    } else if (lowerCaseName == HttpHeaders.HOST) {
      if (value is String) {
        int pos = value.indexOf(":");
        if (pos == -1) {
          _host = value;
          _port = DEFAULT_HTTP_PORT;
        } else {
          if (pos > 0) {
            _host = value.substring(0, pos);
          } else {
            _host = null;
          }
          if (pos + 1 == value.length) {
            _port = DEFAULT_HTTP_PORT;
          } else {
            try {
              _port = int.parse(value.substring(pos + 1));
            } on FormatException catch (e) {
              _port = null;
            }
          }
        }
        _set(HttpHeaders.HOST, value);
      } else {
        throw new HttpException("Unexpected type for header named $name");
      }
    } else if (lowerCaseName == HttpHeaders.CONTENT_TYPE) {
      _set(HttpHeaders.CONTENT_TYPE, value);
    } else {
      _addValue(lowerCaseName, value);
    }
  }

  void _addValue(String name, Object value) {
    List<String> values = _headers[name];
    if (values == null) {
      values = new List<String>();
      _headers[name] = values;
    }
    if (value is DateTime) {
      values.add(RFC_1123_DATE_FORMAT.format(value));
    } else {
      values.add(value.toString());
    }
  }

  void _set(String name, String value) {
    name = name.toLowerCase();
    List<String> values = new List<String>();
    _headers[name] = values;
    values.add(value);
  }

  _checkMutable() {
    if (!_mutable) throw new HttpException("HTTP headers are not mutable");
  }

  _updateHostHeader() {
    bool defaultPort = _port == null || _port == DEFAULT_HTTP_PORT;
    String portPart = defaultPort ? "" : ":$_port";
    _set("host", "$host$portPart");
  }

  _foldHeader(String name) {
    if (name == HttpHeaders.SET_COOKIE ||
        (_noFoldingHeaders != null &&
         _noFoldingHeaders.indexOf(name) != -1)) {
      return false;
    }
    return true;
  }

  void _synchronize() {
    // If the content length is not known make sure chunked transfer
    // encoding is used for HTTP 1.1.
    if (contentLength < 0) {
      if (protocolVersion == "1.0") {
        persistentConnection = false;
      } else {
        chunkedTransferEncoding = true;
      }
    }
    // If a Transfer-Encoding header field is present the
    // Content-Length header MUST NOT be sent (RFC 2616 section 4.4).
    if (chunkedTransferEncoding &&
        contentLength >= 0 &&
        protocolVersion == "1.1") {
      contentLength = -1;
    }
  }

  void _finalize() {
    _synchronize();
    _mutable = false;
  }

  _write(BytesBuilder builder) {
    final COLONSP = const [_CharCode.COLON, _CharCode.SP];
    final COMMASP = const [_CharCode.COMMA, _CharCode.SP];
    final CRLF = const [_CharCode.CR, _CharCode.LF];

    // Format headers.
    _headers.forEach((String name, List<String> values) {
      bool fold = _foldHeader(name);
      var nameData = name.codeUnits;
      builder.add(nameData);
      builder.add(const [_CharCode.COLON, _CharCode.SP]);
      for (int i = 0; i < values.length; i++) {
        if (i > 0) {
          if (fold) {
            builder.add(const [_CharCode.COMMA, _CharCode.SP]);
          } else {
            builder.add(const [_CharCode.CR, _CharCode.LF]);
            builder.add(nameData);
            builder.add(const [_CharCode.COLON, _CharCode.SP]);
          }
        }
        builder.add(values[i].codeUnits);
      }
      builder.add(const [_CharCode.CR, _CharCode.LF]);
    });
  }

  String toString() {
    StringBuffer sb = new StringBuffer();
    _headers.forEach((String name, List<String> values) {
      sb.write(name);
      sb.write(": ");
      bool fold = _foldHeader(name);
      for (int i = 0; i < values.length; i++) {
        if (i > 0) {
          if (fold) {
            sb.write(", ");
          } else {
            sb.write("\n");
            sb.write(name);
            sb.write(": ");
          }
        }
        sb.write(values[i]);
      }
      sb.write("\n");
    });
    return sb.toString();
  }

  bool _mutable = true;  // Are the headers currently mutable?
  Map<String, List<String>> _headers;
  List<String> _noFoldingHeaders;

  int _contentLength = -1;
  bool _chunkedTransferEncoding = false;
  final String protocolVersion;
  String _host;
  int _port;
}

// Frequently used character codes.
class _CharCode {
  static const int HT = 9;
  static const int LF = 10;
  static const int CR = 13;
  static const int SP = 32;
  static const int AMPERSAND = 38;
  static const int COMMA = 44;
  static const int DASH = 45;
  static const int SLASH = 47;
  static const int ZERO = 48;
  static const int ONE = 49;
  static const int COLON = 58;
  static const int SEMI_COLON = 59;
  static const int EQUAL = 61;
}

// from bytes_builder.dart

/**
 * Builds a list of bytes, allowing bytes and lists of bytes to be added at the
 * end.
 *
 * Used to efficiently collect bytes and lists of bytes, using an internal
 * buffer. Note that it's optimized for IO, using an initial buffer of 1K bytes.
 */
class BytesBuilder {
  List<int> _buffer = [];

  /**
   * Construct a new empty [BytesBuilder].
   */
  BytesBuilder();

  /**
   * Appends [bytes] to the current contents of the builder.
   *
   * Each value of [bytes] will be bit-representation truncated to the range
   * 0 .. 255.
   */
  void add(List<int> bytes) => _buffer.addAll(bytes);

  /**
   * Append [byte] to the current contents of the builder.
   *
   * The [byte] will be bit-representation truncated to the range 0 .. 255.
   */
  void addByte(int byte) => _buffer.add(byte);

  /**
   * Returns the contents of `this` and clears `this`.
   *
   * The list returned is a view of the the internal buffer, limited to the
   * [length].
   */
  List<int> takeBytes() {
    List copy = _buffer.sublist(0);
    _buffer.clear();
    return copy;
  }

  /**
   * Returns a copy of the current contents of the builder.
   *
   * Leaves the contents of the builder intact.
   */
  List<int> toBytes() => _buffer.sublist(0);

  /**
   * The number of bytes in the builder.
   */
  int get length => _buffer.length;

  /**
   * Returns `true` if the buffer is empty.
   */
  bool get isEmpty => _buffer.isEmpty;

  /**
   * Returns `true` if the buffer is empty.
   */
  bool get isNotEmpty => _buffer.isNotEmpty;

  /**
   * Clear the contents of the builder.
   */
  void clear() => _buffer.clear();
}
