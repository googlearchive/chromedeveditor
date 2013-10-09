
library http;

import 'dart:async';

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
   * Gets and sets the content type. Note that the content type in the
   * header will only be updated if this field is set
   * directly. Mutating the returned current value will have no
   * effect.
   */
  ContentType contentType;

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


/**
 * A server that delivers content, such as web pages, using
 * the HTTP protocol.
 *
 * The [HttpServer] is a [Stream] of [HttpRequest]s. Each
 * [HttpRequest] has an associated [HttpResponse] object as its
 * [HttpRequest.response] member, and the server responds to a request by
 * writing to that [HttpResponse] object.
 *
 * Incomplete requests where all or parts of the header is missing, are
 * ignored and no exceptions or [HttpRequest] objects are generated for them.
 * Likewise, when writing to a [HttpResponse], any [Socket] exceptions are
 * ignored and any future writes are ignored.
 *
 * The [HttpRequest] exposes the request headers, and provides the request body,
 * if it exists, as a stream of data. If the body is unread, it'll be drained
 * when the [HttpResponse] is being written to or closed.
 *
 * The following example shows how to bind a [HttpServer] to a IPv6
 * [InternetAddress] on port 80, and listening to requests.
 *
 *   HttpServer.bind(InternetAddress.ANY_IP_V6, 80).then((server) {
 *     server.listen((HttpRequest request) {
 *       // Handle requests.
 *     });
 *   });
 */
abstract class HttpServer implements Stream<HttpRequest> {
  /**
   * Starts listening for HTTP requests on the specified [address] and
   * [port].
   *
   * The [address] can either be a [String] or an
   * [InternetAddress]. If [address] is a [String], [bind] will
   * perform a [InternetAddress.lookup] and use the first value in the
   * list. To listen on the loopback adapter, which will allow only
   * incoming connections from the local host, use the value
   * [InternetAddress.LOOPBACK_IP_V4] or
   * [InternetAddress.LOOPBACK_IP_V6]. To allow for incoming
   * connection from the network use either one of the values
   * [InternetAddress.ANY_IP_V4] or [InternetAddress.ANY_IP_V6] to
   * bind to all interfaces or the IP address of a specific interface.
   *
   * If an IP version 6 (IPv6) address is used, both IP version 6
   * (IPv6) and version 4 (IPv4) connections will be accepted. To
   * restrict this to version 6 (IPv6) only, use [HttpServer.listenOn]
   * with a [ServerSocket] configured for IP version 6 connections
   * only.
   *
   * If [port] has the value [:0:] an ephemeral port will be chosen by
   * the system. The actual port used can be retrieved using the
   * [port] getter.
   *
   * The optional argument [backlog] can be used to specify the listen
   * backlog for the underlying OS listen setup. If [backlog] has the
   * value of [:0:] (the default) a reasonable value will be chosen by
   * the system.
   */
  static Future<HttpServer> bind(address,
                                 int port,
                                 {int backlog: 0})
      => _HttpServer.bind(address, port, backlog);

  /**
   * The [address] can either be a [String] or an
   * [InternetAddress]. If [address] is a [String], [bind] will
   * perform a [InternetAddress.lookup] and use the first value in the
   * list. To listen on the loopback adapter, which will allow only
   * incoming connections from the local host, use the value
   * [InternetAddress.LOOPBACK_IP_V4] or
   * [InternetAddress.LOOPBACK_IP_V6]. To allow for incoming
   * connection from the network use either one of the values
   * [InternetAddress.ANY_IP_V4] or [InternetAddress.ANY_IP_V6] to
   * bind to all interfaces or the IP address of a specific interface.
   *
   * If an IP version 6 (IPv6) address is used, both IP version 6
   * (IPv6) and version 4 (IPv4) connections will be accepted. To
   * restrict this to version 6 (IPv6) only, use [HttpServer.listenOn]
   * with a [ServerSocket] configured for IP version 6 connections
   * only.
   *
   * If [port] has the value [:0:] an ephemeral port will be chosen by
   * the system. The actual port used can be retrieved using the
   * [port] getter.
   *
   * The optional argument [backlog] can be used to specify the listen
   * backlog for the underlying OS listen setup. If [backlog] has the
   * value of [:0:] (the default) a reasonable value will be chosen by
   * the system.
   *
   * The certificate with nickname or distinguished name (DN) [certificateName]
   * is looked up in the certificate database, and is used as the server
   * certificate. If [requestClientCertificate] is true, the server will
   * request clients to authenticate with a client certificate.
   */

  static Future<HttpServer> bindSecure(address,
                                       int port,
                                       {int backlog: 0,
                                        String certificateName,
                                        bool requestClientCertificate: false})
      => _HttpServer.bindSecure(address,
                                port,
                                backlog,
                                certificateName,
                                requestClientCertificate);

  /**
   * Attaches the HTTP server to an existing [ServerSocket]. When the
   * [HttpServer] is closed, the [HttpServer] will just detach itself,
   * closing current connections but not closing [serverSocket].
   */
  factory HttpServer.listenOn(ServerSocket serverSocket)
      => new _HttpServer.listenOn(serverSocket);

  /**
   * Permanently stops this [HttpServer] from listening for new
   * connections.  This closes this [Stream] of [HttpRequest]s with a
   * done event. The returned future completes when the server is
   * stopped. For a server started using [bind] or [bindSecure] this
   * means that the port listened on no longer in use.
   */
  Future close();

  /**
   * Returns the port that the server is listening on. This can be
   * used to get the actual port used when a value of 0 for [:port:] is
   * specified in the [bind] or [bindSecure] call.
   */
  int get port;

  /**
   * Returns the address that the server is listening on. This can be
   * used to get the actual address used, when the address is fetched by
   * a lookup from a hostname.
   */
  InternetAddress get address;

  /**
   * Sets the timeout, in seconds, for sessions of this [HttpServer].
   * The default timeout is 20 minutes.
   */
  set sessionTimeout(int timeout);

  /**
   * Set and get the default value of the `Server` header for all responses
   * generated by this [HttpServer]. The default value is
   * `Dart/<version> (dart:io)`.
   *
   * If the serverHeader is set to `null`, no default `Server` header will be
   * added to each response.
   */
  String serverHeader;

  /**
   * Get or set the timeout used for idle keep-alive connections. If no further
   * request is seen within [idleTimeout] after the previous request was
   * completed, the connection is droped.
   *
   * Default is 120 seconds.
   *
   * To disable, set [idleTimeout] to `null`.
   */
  Duration idleTimeout;
}


/**
 * A server-side object
 * that contains the content of and information about an HTTP request.
 *
 * __Note__: Check out the
 * [http_server](http://pub.dartlang.org/packages/http_server)
 * package, which makes working with the low-level
 * dart:io HTTP server subsystem easier.
 *
 * HttpRequest objects are generated by an [HttpServer],
 * which listens for HTTP requests on a specific host and port.
 * For each request received, the HttpServer, which is a [Stream],
 * generates an HttpRequest object and adds it to the stream.
 *
 * An HttpRequest object delivers the body content of the request
 * as a stream of bytes.
 * The object also contains information about the request,
 * such as the method, URI, and headers.
 *
 * In the following code, an HttpServer listens
 * for HTTP requests and, within the callback function,
 * uses the HttpRequest object's `method` property to dispatch requests.
 *
 *     final HOST = InternetAddress.LOOPBACK_IP_V4;
 *     final PORT = 4040;
 *
 *     HttpServer.bind(HOST, PORT).then((_server) {
 *       _server.listen((HttpRequest request) {
 *         switch (request.method) {
 *           case 'GET':
 *             handleGetRequest(request);
 *             break;
 *           case 'POST':
 *             ...
 *         }
 *       },
 *       onError: handleError);    // listen() failed.
 *     }).catchError(handleError);
 *
 * Listen to the HttpRequest stream to handle the
 * data and be notified once the entire body is received.
 * An HttpRequest object contains an [HttpResponse] object,
 * to which the server can write its response.
 * For example, here's a skeletal callback function
 * that responds to a request:
 *
 *     void handleGetRequest(HttpRequest req) {
 *       HttpResponse res = req.response;
 *       var body = [];
 *       req.listen((List<int> buffer) => body.add(buffer),
 *         onDone: () {
 *           res.write('Received ${body.length} for request ');
 *           res.write(' ${req.method}: ${req.uri.path}');
 *           res.close();
 *         },
 *         onError: handleError);
 *     }
 */
abstract class HttpRequest implements Stream<List<int>> {
  /**
   * The content length of the request body (read-only).
   *
   * If the size of the request body is not known in advance,
   * this value is -1.
   */
  int get contentLength;

  /**
   * The method, such as 'GET' or 'POST', for the request (read-only).
   */
  String get method;

  /**
   * The URI for the request (read-only).
   *
   * This provides access to the
   * path, query string, and fragment identifier for the request.
   */
  Uri get uri;

  /**
   * The request headers (read-only).
   */
  HttpHeaders get headers;

  /**
   * The cookies in the request, from the Cookie headers (read-only).
   */
  List<Cookie> get cookies;

  /**
   * The persistent connection state signaled by the client (read-only).
   */
  bool get persistentConnection;

  /**
   * The HTTP protocol version used in the request,
   * either "1.0" or "1.1" (read-only).
   */
  String get protocolVersion;

  /**
   * The [HttpResponse] object, used for sending back the response to the
   * client (read-only).
   *
   * If the [contentLength] of the body isn't 0, and the body isn't being read,
   * any write calls on the [HttpResponse] automatically drain the request
   * body.
   */
  HttpResponse get response;
}

/**
 * An [HttpResponse] represents the headers and data to be returned to
 * a client in response to an HTTP request.
 *
 * This object has a number of properties for setting up the HTTP
 * header of the response. When the header has been set up the methods
 * from the [IOSink] can be used to write the actual body of the HTTP
 * response. When one of the [IOSink] methods is used for the
 * first time the request header is send. Calling any methods that
 * will change the header after it is sent will throw an exception.
 *
 * When writing string data through the [IOSink] the encoding used
 * will be determined from the "charset" parameter of the
 * "Content-Type" header.
 *
 *     HttpResponse response = ...
 *     response.headers.contentType
 *         = new ContentType("application", "json", charset: "utf-8");
 *     response.write(...);  // Strings written will be UTF-8 encoded.
 *
 * If no charset is provided the default of ISO-8859-1 (Latin 1) will
 * be used.
 *
 *     HttpResponse response = ...
 *     response.headers.add(HttpHeaders.CONTENT_TYPE, "text/plain");
 *     response.write(...);  // Strings written will be ISO-8859-1 encoded.
 *
 * If an unsupported encoding is used an exception will be thrown if
 * using one of the write methods taking a string.
 */
abstract class HttpResponse implements StreamSink<List<int>> {
  // TODO(ajohnsen): Add documentation of how to pipe a file to the response.
  /**
   * Gets and sets the content length of the response. If the size of
   * the response is not known in advance set the content length to
   * -1 - which is also the default if not set.
   */
  int contentLength;

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

  /**
   * Gets and sets the persistent connection state. The initial value
   * of this property is the persistent connection state from the
   * request.
   */
  bool persistentConnection;

  /**
   * Set and get the [deadline] for the response. The deadline is timed from the
   * time it's set. Setting a new deadline will override any previous deadline.
   * When a deadline is exceeded, the response will be closed and any further
   * data ignored.
   *
   * To disable a deadline, set the [deadline] to `null`.
   *
   * The [deadline] is `null` by default.
   */
  Duration deadline;

  /**
   * Returns the response headers.
   */
  HttpHeaders get headers;

  /**
   * Cookies to set in the client (in the 'set-cookie' header).
   */
  List<Cookie> get cookies;

  /**
   * Respond with a redirect to [location].
   *
   * The URI in [location] should be absolute, but there are no checks
   * to enforce that.
   *
   * By default the HTTP status code `HttpStatus.MOVED_TEMPORARILY`
   * (`302`) is used for the redirect, but an alternative one can be
   * specified using the [status] argument.
   *
   * This method will also call `close`, and the returned future is
   * the furure returned by `close`.
   */
  Future redirect(Uri location, {int status: HttpStatus.MOVED_TEMPORARILY});
}

/**
 * Representation of a content type. An instance of [ContentType] is
 * immutable.
 */
abstract class ContentType implements HeaderValue {
  /**
   * Creates a new content type object setting the primary type and
   * sub type. The charset and additional parameters can also be set
   * using [charset] and [parameters]. If charset is passed and
   * [parameters] contains charset as well the passed [charset] will
   * override the value in parameters. Keys and values passed in
   * parameters will be converted to lower case.
   */
  factory ContentType(String primaryType,
                      String subType,
                      {String charset, Map<String, String> parameters}) {
    return new _ContentType(primaryType, subType, charset, parameters);
  }

  /**
   * Creates a new content type object from parsing a Content-Type
   * header value. As primary type, sub type and parameter names and
   * values are not case sensitive all these values will be converted
   * to lower case. Parsing this string
   *
   *     text/html; charset=utf-8
   *
   * will create a content type object with primary type [:text:], sub
   * type [:html:] and parameter [:charset:] with value [:utf-8:].
   */
  static ContentType parse(String value) {
    return _ContentType.parse(value);
  }

  /**
   * Gets the mime-type, without any parameters.
   */
  String get mimeType;

  /**
   * Gets the primary type.
   */
  String get primaryType;

  /**
   * Gets the sub type.
   */
  String get subType;

  /**
   * Gets the character set.
   */
  String get charset;
}

/**
 * Representation of a cookie. For cookies received by the server as
 * Cookie header values only [:name:] and [:value:] fields will be
 * set. When building a cookie for the 'set-cookie' header in the server
 * and when receiving cookies in the client as 'set-cookie' headers all
 * fields can be used.
 */
abstract class Cookie {
  /**
   * Creates a new cookie optionally setting the name and value.
   */
  factory Cookie([String name, String value]) => new _Cookie(name, value);

  /**
   * Creates a new cookie by parsing a header value from a 'set-cookie'
   * header.
   */
  factory Cookie.fromSetCookieValue(String value) {
    return new _Cookie.fromSetCookieValue(value);
  }

  /**
   * Gets and sets the name.
   */
  String name;

  /**
   * Gets and sets the value.
   */
  String value;

  /**
   * Gets and sets the expiry date.
   */
  DateTime expires;

  /**
   * Gets and sets the max age. A value of [:0:] means delete cookie
   * now.
   */
  int maxAge;

  /**
   * Gets and sets the domain.
   */
  String domain;

  /**
   * Gets and sets the path.
   */
  String path;

  /**
   * Gets and sets whether this cookie is secure.
   */
  bool secure;

  /**
   * Gets and sets whether this cookie is HTTP only.
   */
  bool httpOnly;

  /**
   * Returns the formatted string representation of the cookie. The
   * string representation can be used for for setting the Cookie or
   * 'set-cookie' headers
   */
  String toString();
}

/**
 * Representation of a header value in the form:
 *
 *   [:value; parameter1=value1; parameter2=value2:]
 *
 * [HeaderValue] can be used to conveniently build and parse header
 * values on this form.
 *
 * To build an [:accepts:] header with the value
 *
 *     text/plain; q=0.3, text/html
 *
 * use code like this:
 *
 *     HttpClientRequest request = ...;
 *     var v = new HeaderValue("text/plain", {"q": "0.3"});
 *     request.headers.add(HttpHeaders.ACCEPT, v);
 *     request.headers.add(HttpHeaders.ACCEPT, "text/html");
 *
 * To parse the header values use the [:parse:] static method.
 *
 *     HttpRequest request = ...;
 *     List<String> values = request.headers[HttpHeaders.ACCEPT];
 *     values.forEach((value) {
 *       HeaderValue v = HeaderValue.parse(value);
 *       // Use v.value and v.parameters
 *     });
 *
 * An instance of [HeaderValue] is immutable.
 */
abstract class HeaderValue {
  /**
   * Creates a new header value object setting the value and parameters.
   */
  factory HeaderValue([String value = "", Map<String, String> parameters]) {
    return new _HeaderValue(value, parameters);
  }

  /**
   * Creates a new header value object from parsing a header value
   * string with both value and optional parameters.
   */
  static HeaderValue parse(String value,
                           {String parameterSeparator: ";"}) {
    return _HeaderValue.parse(value, parameterSeparator: parameterSeparator);
  }

  /**
   * Gets the header value.
   */
  String get value;

  /**
   * Gets the map of parameters.
   *
   * This map cannot be modified. invoking any operation which would
   * modify the map will throw [UnsupportedError].
   */
  Map<String, String> get parameters;

  /**
   * Returns the formatted string representation in the form:
   *
   *     value; parameter1=value1; parameter2=value2
   */
  String toString();
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

// socket.dart

/**
 * [InternetAddressType] is the type an [InternetAddress]. Currently,
 * IP version 4 (IPv4) and IP version 6 (IPv6) are supported.
 */
class InternetAddressType {
  static const InternetAddressType IP_V4 = const InternetAddressType._(0);
  static const InternetAddressType IP_V6 = const InternetAddressType._(1);
  static const InternetAddressType ANY = const InternetAddressType._(-1);

  final int _value;

  const InternetAddressType._(int this._value);

  factory InternetAddressType._from(int value) {
    if (value == 0) return IP_V4;
    if (value == 1) return IP_V6;
    throw new ArgumentError("Invalid type: $value");
  }

  /**
   * Get the name of the type, e.g. "IP_V4" or "IP_V6".
   */
  String get name {
    switch (_value) {
      case -1: return "ANY";
      case 0: return "IP_V4";
      case 1: return "IP_V6";
      default: throw new ArgumentError("Invalid InternetAddress");
    }
  }

  String toString() => "InternetAddressType: $name";
}

/**
 * The [InternetAddress] is an object reflecting either a remote or a
 * local address. When combined with a port number, this represents a
 * endpoint that a socket can connect to or a listening socket can
 * bind to.
 */
abstract class InternetAddress {
  /**
   * IP version 4 loopback address. Use this address when listening on
   * or connecting to the loopback adapter using IP version 4 (IPv4).
   */
  external static InternetAddress get LOOPBACK_IP_V4;

  /**
   * IP version 6 loopback address. Use this address when listening on
   * or connecting to the loopback adapter using IP version 6 (IPv6).
   */
  external static InternetAddress get LOOPBACK_IP_V6;

  /**
   * IP version 4 any address. Use this address when listening on
   * all adapters IP addresses using IP version 4 (IPv4).
   */
  external static InternetAddress get ANY_IP_V4;

  /**
   * IP version 6 any address. Use this address when listening on
   * all adapters IP addresses using IP version 6 (IPv6).
   */
  external static InternetAddress get ANY_IP_V6;

  /**
   * The [type] of the [InternetAddress] specified what IP protocol.
   */
  InternetAddressType type;

  /**
   * The resolved address of the host.
   */
  String get address;

  /**
   * The host used to lookup the address.
   */
  String get host;

  /**
   * Returns true if the [InternetAddress] is a loopback address.
   */
  bool get isLoopback;

  /**
   * Returns true if the [InternetAddress]s scope is a link-local.
   */
  bool get isLinkLocal;

  /**
   * Perform a reverse dns lookup on the [address], creating a new
   * [InternetAddress] where the host field set to the result.
   */
  Future<InternetAddress> reverse();

  /**
   * Lookup a host, returning a Future of a list of
   * [InternetAddress]s. If [type] is [InternetAddressType.ANY], it
   * will lookup both IP version 4 (IPv4) and IP version 6 (IPv6)
   * addresses. If [type] is either [InternetAddressType.IP_V4] or
   * [InternetAddressType.IP_V6] it will only lookup addresses of the
   * specified type. The order of the list can, and most likely will,
   * change over time.
   */
  external static Future<List<InternetAddress>> lookup(
      String host, {InternetAddressType type: InternetAddressType.ANY});
}

// http_date.dart

/**
 * Utility functions for working with dates with HTTP specific date
 * formats.
 */
class HttpDate {
  // From RFC-2616 section "3.3.1 Full Date",
  // http://tools.ietf.org/html/rfc2616#section-3.3.1
  //
  // HTTP-date    = rfc1123-date | rfc850-date | asctime-date
  // rfc1123-date = wkday "," SP date1 SP time SP "GMT"
  // rfc850-date  = weekday "," SP date2 SP time SP "GMT"
  // asctime-date = wkday SP date3 SP time SP 4DIGIT
  // date1        = 2DIGIT SP month SP 4DIGIT
  //                ; day month year (e.g., 02 Jun 1982)
  // date2        = 2DIGIT "-" month "-" 2DIGIT
  //                ; day-month-year (e.g., 02-Jun-82)
  // date3        = month SP ( 2DIGIT | ( SP 1DIGIT ))
  //                ; month day (e.g., Jun  2)
  // time         = 2DIGIT ":" 2DIGIT ":" 2DIGIT
  //                ; 00:00:00 - 23:59:59
  // wkday        = "Mon" | "Tue" | "Wed"
  //              | "Thu" | "Fri" | "Sat" | "Sun"
  // weekday      = "Monday" | "Tuesday" | "Wednesday"
  //              | "Thursday" | "Friday" | "Saturday" | "Sunday"
  // month        = "Jan" | "Feb" | "Mar" | "Apr"
  //              | "May" | "Jun" | "Jul" | "Aug"
  //              | "Sep" | "Oct" | "Nov" | "Dec"

  /**
   * Format a date according to
   * [RFC-1123](http://tools.ietf.org/html/rfc1123 "RFC-1123"),
   * e.g. `Thu, 1 Jan 1970 00:00:00 GMT`.
   */
  static String format(DateTime date) {
    const List wkday = const ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    const List month = const ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                              "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

    DateTime d = date.toUtc();
    StringBuffer sb = new StringBuffer();
    sb.write(wkday[d.weekday - 1]);
    sb.write(", ");
    sb.write(d.day.toString());
    sb.write(" ");
    sb.write(month[d.month - 1]);
    sb.write(" ");
    sb.write(d.year.toString());
    sb.write(d.hour < 9 ? " 0" : " ");
    sb.write(d.hour.toString());
    sb.write(d.minute < 9 ? ":0" : ":");
    sb.write(d.minute.toString());
    sb.write(d.second < 9 ? ":0" : ":");
    sb.write(d.second.toString());
    sb.write(" GMT");
    return sb.toString();
  }

  /**
   * Parse a date string in either of the formats
   * [RFC-1123](http://tools.ietf.org/html/rfc1123 "RFC-1123"),
   * [RFC-850](http://tools.ietf.org/html/rfc850 "RFC-850") or
   * ANSI C's asctime() format. These formats are listed here.
   *
   *     Thu, 1 Jan 1970 00:00:00 GMT
   *     Thursday, 1-Jan-1970 00:00:00 GMT
   *     Thu Jan  1 00:00:00 1970
   *
   * For more information see [RFC-2616 section 3.1.1]
   * (http://tools.ietf.org/html/rfc2616#section-3.3.1
   * "RFC-2616 section 3.1.1").
   */
  static DateTime parse(String date) {
    final int SP = 32;
    const List wkdays = const ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    const List weekdays = const ["Monday", "Tuesday", "Wednesday", "Thursday",
                           "Friday", "Saturday", "Sunday"];
    const List months = const ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                         "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    const List wkdaysLowerCase =
        const ["mon", "tue", "wed", "thu", "fri", "sat", "sun"];
    const List weekdaysLowerCase = const ["monday", "tuesday", "wednesday",
                                          "thursday", "friday", "saturday",
                                          "sunday"];
    const List monthsLowerCase = const ["jan", "feb", "mar", "apr", "may",
                                        "jun", "jul", "aug", "sep", "oct",
                                        "nov", "dec"];

    final int formatRfc1123 = 0;
    final int formatRfc850 = 1;
    final int formatAsctime = 2;

    int index = 0;
    String tmp;
    int format;

    void expect(String s) {
      if (date.length - index < s.length) {
        throw new HttpException("Invalid HTTP date $date");
      }
      String tmp = date.substring(index, index + s.length);
      if (tmp != s) {
        throw new HttpException("Invalid HTTP date $date");
      }
      index += s.length;
    }

    int expectWeekday() {
      int weekday;
      // The formatting of the weekday signals the format of the date string.
      int pos = date.indexOf(",", index);
      if (pos == -1) {
        int pos = date.indexOf(" ", index);
        if (pos == -1) throw new HttpException("Invalid HTTP date $date");
        tmp = date.substring(index, pos);
        index = pos + 1;
        weekday = wkdays.indexOf(tmp);
        if (weekday != -1) {
          format = formatAsctime;
          return weekday;
        }
      } else {
        tmp = date.substring(index, pos);
        index = pos + 1;
        weekday = wkdays.indexOf(tmp);
        if (weekday != -1) {
          format = formatRfc1123;
          return weekday;
        }
        weekday = weekdays.indexOf(tmp);
        if (weekday != -1) {
          format = formatRfc850;
          return weekday;
        }
      }
      throw new HttpException("Invalid HTTP date $date");
    }

    int expectMonth(String separator) {
      int pos = date.indexOf(separator, index);
      if (pos - index != 3) throw new HttpException("Invalid HTTP date $date");
      tmp = date.substring(index, pos);
      index = pos + 1;
      int month = months.indexOf(tmp);
      if (month != -1) return month;
      throw new HttpException("Invalid HTTP date $date");
    }

    int expectNum(String separator) {
      int pos;
      if (separator.length > 0) {
        pos = date.indexOf(separator, index);
      } else {
        pos = date.length;
      }
      String tmp = date.substring(index, pos);
      index = pos + separator.length;
      try {
        int value = int.parse(tmp);
        return value;
      } on FormatException catch (e) {
        throw new HttpException("Invalid HTTP date $date");
      }
    }

    void expectEnd() {
      if (index != date.length) {
        throw new HttpException("Invalid HTTP date $date");
      }
    }

    int weekday = expectWeekday();
    int day;
    int month;
    int year;
    int hours;
    int minutes;
    int seconds;
    if (format == formatAsctime) {
      month = expectMonth(" ");
      if (date.codeUnitAt(index) == SP) index++;
      day = expectNum(" ");
      hours = expectNum(":");
      minutes = expectNum(":");
      seconds = expectNum(" ");
      year = expectNum("");
    } else {
      expect(" ");
      day = expectNum(format == formatRfc1123 ? " " : "-");
      month = expectMonth(format == formatRfc1123 ? " " : "-");
      year = expectNum(" ");
      hours = expectNum(":");
      minutes = expectNum(":");
      seconds = expectNum(" ");
      expect("GMT");
    }
    expectEnd();
    return new DateTime.utc(year, month + 1, day, hours, minutes, seconds, 0);
  }

  // Parse a cookie date string.
  static DateTime _parseCookieDate(String date) {
    const List monthsLowerCase = const ["jan", "feb", "mar", "apr", "may",
                                        "jun", "jul", "aug", "sep", "oct",
                                        "nov", "dec"];

    int position = 0;

    void error() {
      throw new HttpException("Invalid cookie date $date");
    }

    bool isEnd() {
      return position == date.length;
    }

    bool isDelimiter(String s) {
      int char = s.codeUnitAt(0);
      if (char == 0x09) return true;
      if (char >= 0x20 && char <= 0x2F) return true;
      if (char >= 0x3B && char <= 0x40) return true;
      if (char >= 0x5B && char <= 0x60) return true;
      if (char >= 0x7B && char <= 0x7E) return true;
      return false;
    }

    bool isNonDelimiter(String s) {
      int char = s.codeUnitAt(0);
      if (char >= 0x00 && char <= 0x08) return true;
      if (char >= 0x0A && char <= 0x1F) return true;
      if (char >= 0x30 && char <= 0x39) return true;  // Digit
      if (char == 0x3A) return true;  // ':'
      if (char >= 0x41 && char <= 0x5A) return true;  // Alpha
      if (char >= 0x61 && char <= 0x7A) return true;  // Alpha
      if (char >= 0x7F && char <= 0xFF) return true;  // Alpha
      return false;
    }

    bool isDigit(String s) {
      int char = s.codeUnitAt(0);
      if (char > 0x2F && char < 0x3A) return true;
      return false;
    }

    int getMonth(String month) {
      if (month.length < 3) return -1;
      return monthsLowerCase.indexOf(month.substring(0, 3));
    }

    int toInt(String s) {
      int index = 0;
      for (; index < s.length && isDigit(s[index]); index++);
      return int.parse(s.substring(0, index));
    }

    var tokens = [];
    while (!isEnd()) {
      while (!isEnd() && isDelimiter(date[position])) position++;
      int start = position;
      while (!isEnd() && isNonDelimiter(date[position])) position++;
      tokens.add(date.substring(start, position).toLowerCase());
      while (!isEnd() && isDelimiter(date[position])) position++;
    }

    String timeStr;
    String dayOfMonthStr;
    String monthStr;
    String yearStr;

    for (var token in tokens) {
      if (token.length < 1) continue;
      if (timeStr == null && token.length >= 5 && isDigit(token[0]) &&
          (token[1] == ":" || (isDigit(token[1]) && token[2] == ":"))) {
        timeStr = token;
      } else if (dayOfMonthStr == null && isDigit(token[0])) {
        dayOfMonthStr = token;
      } else if (monthStr == null && getMonth(token) >= 0) {
        monthStr = token;
      } else if (yearStr == null && token.length >= 2 &&
                 isDigit(token[0]) && isDigit(token[1])) {
        yearStr = token;
      }
    }

    if (timeStr == null || dayOfMonthStr == null ||
        monthStr == null || yearStr == null) {
      error();
    }

    int year = toInt(yearStr);
    if (year >= 70 && year <= 99) year += 1900;
    else if (year >= 0 && year <= 69) year += 2000;
    if (year < 1601) error();

    int dayOfMonth = toInt(dayOfMonthStr);
    if (dayOfMonth < 1 || dayOfMonth > 31) error();

    int month = getMonth(monthStr) + 1;

    var timeList = timeStr.split(":");
    if (timeList.length != 3) error();
    int hour = toInt(timeList[0]);
    int minute = toInt(timeList[1]);
    int second = toInt(timeList[2]);
    if (hour > 23) error();
    if (minute > 59) error();
    if (second > 59) error();

    return new DateTime.utc(year, month, dayOfMonth, hour, minute, second, 0);
  }
}

// TODO: implementation


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
        return HttpDate.parse(values[0]);
      } on Exception catch (e) {
        return null;
      }
    }
    return null;
  }

  void set ifModifiedSince(DateTime ifModifiedSince) {
    _checkMutable();
    // Format "ifModifiedSince" header with date in Greenwich Mean Time (GMT).
    String formatted = HttpDate.format(ifModifiedSince.toUtc());
    _set(HttpHeaders.IF_MODIFIED_SINCE, formatted);
  }

  DateTime get date {
    List<String> values = _headers[HttpHeaders.DATE];
    if (values != null) {
      try {
        return HttpDate.parse(values[0]);
      } on Exception catch (e) {
        return null;
      }
    }
    return null;
  }

  void set date(DateTime date) {
    _checkMutable();
    // Format "DateTime" header with date in Greenwich Mean Time (GMT).
    String formatted = HttpDate.format(date.toUtc());
    _set("date", formatted);
  }

  DateTime get expires {
    List<String> values = _headers[HttpHeaders.EXPIRES];
    if (values != null) {
      try {
        return HttpDate.parse(values[0]);
      } on Exception catch (e) {
        return null;
      }
    }
    return null;
  }

  void set expires(DateTime expires) {
    _checkMutable();
    // Format "Expires" header with date in Greenwich Mean Time (GMT).
    String formatted = HttpDate.format(expires.toUtc());
    _set(HttpHeaders.EXPIRES, formatted);
  }

  ContentType get contentType {
    var values = _headers["content-type"];
    if (values != null) {
      return ContentType.parse(values[0]);
    } else {
      return null;
    }
  }

  void set contentType(ContentType contentType) {
    _checkMutable();
    _set(HttpHeaders.CONTENT_TYPE, contentType.toString());
  }

  void _add(String name, value) {
    var lowerCaseName = name.toLowerCase();
    // TODO(sgjesse): Add immutable state throw HttpException is immutable.
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
          _port = HttpClient.DEFAULT_HTTP_PORT;
        } else {
          if (pos > 0) {
            _host = value.substring(0, pos);
          } else {
            _host = null;
          }
          if (pos + 1 == value.length) {
            _port = HttpClient.DEFAULT_HTTP_PORT;
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
      values.add(HttpDate.format(value));
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
    bool defaultPort = _port == null || _port == HttpClient.DEFAULT_HTTP_PORT;
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

  List<Cookie> _parseCookies() {
    // Parse a Cookie header value according to the rules in RFC 6265.
    var cookies = new List<Cookie>();
    void parseCookieString(String s) {
      int index = 0;

      bool done() => index == s.length;

      void skipWS() {
        while (!done()) {
         if (s[index] != " " && s[index] != "\t") return;
         index++;
        }
      }

      String parseName() {
        int start = index;
        while (!done()) {
          if (s[index] == " " || s[index] == "\t" || s[index] == "=") break;
          index++;
        }
        return s.substring(start, index);
      }

      String parseValue() {
        int start = index;
        while (!done()) {
          if (s[index] == " " || s[index] == "\t" || s[index] == ";") break;
          index++;
        }
        return s.substring(start, index);
      }

      void expect(String expected) {
        if (done()) {
          throw new HttpException("Failed to parse header value [$s]");
        }
        if (s[index] != expected) {
          throw new HttpException("Failed to parse header value [$s]");
        }
        index++;
      }

      while (!done()) {
        skipWS();
        if (done()) return;
        String name = parseName();
        skipWS();
        expect("=");
        skipWS();
        String value = parseValue();
        cookies.add(new _Cookie(name, value));
        skipWS();
        if (done()) return;
        expect(";");
      }
    }
    List<String> values = _headers[HttpHeaders.COOKIE];
    if (values != null) {
      values.forEach((headerValue) => parseCookieString(headerValue));
    }
    return cookies;
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

class _HeaderValue implements HeaderValue {
  String _value;
  _UnmodifiableMap<String, String> _parameters;

  _HeaderValue([String this._value = "", Map<String, String> parameters]) {
    if (parameters != null) {
      _parameters =
          new _UnmodifiableMap(new Map<String, String>.from(parameters));
    }
  }

  static _HeaderValue parse(String value, {parameterSeparator: ";"}) {
    // Parse the string.
    var result = new _HeaderValue();
    result._parse(value, parameterSeparator);
    return result;
  }

  String get value => _value;

  void _ensureParameters() {
    if (_parameters == null) {
      _parameters = new _UnmodifiableMap(new Map<String, String>());
    }
  }

  Map<String, String> get parameters {
    _ensureParameters();
    return _parameters;
  }

  String toString() {
    StringBuffer sb = new StringBuffer();
    sb.write(_value);
    if (parameters != null && parameters.length > 0) {
      _parameters.forEach((String name, String value) {
        sb.write("; ");
        sb.write(name);
        sb.write("=");
        sb.write(value);
      });
    }
    return sb.toString();
  }

  void _parse(String s, String parameterSeparator) {
    int index = 0;

    bool done() => index == s.length;

    void skipWS() {
      while (!done()) {
        if (s[index] != " " && s[index] != "\t") return;
        index++;
      }
    }

    String parseValue() {
      int start = index;
      while (!done()) {
        if (s[index] == " " ||
            s[index] == "\t" ||
            s[index] == parameterSeparator) break;
        index++;
      }
      return s.substring(start, index);
    }

    void expect(String expected) {
      if (done() || s[index] != expected) {
        throw new HttpException("Failed to parse header value");
      }
      index++;
    }

    void maybeExpect(String expected) {
      if (s[index] == expected) index++;
    }

    void parseParameters() {
      var parameters = new Map<String, String>();
      _parameters = new _UnmodifiableMap(parameters);

      String parseParameterName() {
        int start = index;
        while (!done()) {
          if (s[index] == " " || s[index] == "\t" || s[index] == "=") break;
          index++;
        }
        return s.substring(start, index).toLowerCase();
      }

      String parseParameterValue() {
        if (s[index] == "\"") {
          // Parse quoted value.
          StringBuffer sb = new StringBuffer();
          index++;
          while (!done()) {
            if (s[index] == "\\") {
              if (index + 1 == s.length) {
                throw new HttpException("Failed to parse header value");
              }
              index++;
            } else if (s[index] == "\"") {
              index++;
              break;
            }
            sb.write(s[index]);
            index++;
          }
          return sb.toString();
        } else {
          // Parse non-quoted value.
          return parseValue();
        }
      }

      while (!done()) {
        skipWS();
        if (done()) return;
        String name = parseParameterName();
        skipWS();
        expect("=");
        skipWS();
        String value = parseParameterValue();
        parameters[name] = value;
        skipWS();
        if (done()) return;
        expect(parameterSeparator);
      }
    }

    skipWS();
    _value = parseValue();
    skipWS();
    if (done()) return;
    maybeExpect(parameterSeparator);
    parseParameters();
  }
}

class _ContentType extends _HeaderValue implements ContentType {
  String _primaryType = "";
  String _subType = "";

  _ContentType(String primaryType,
               String subType,
               String charset,
               Map<String, String> parameters)
      : _primaryType = primaryType, _subType = subType, super("") {
    if (_primaryType == null) _primaryType = "";
    if (_subType == null) _subType = "";
    _value = "$_primaryType/$_subType";
    if (parameters != null) {
      _ensureParameters();
      parameters.forEach((String key, String value) {
        this._parameters._map[key.toLowerCase()] = value.toLowerCase();
      });
    }
    if (charset != null) {
      _ensureParameters();
      this._parameters._map["charset"] = charset.toLowerCase();
    }
  }

  _ContentType._();

  static _ContentType parse(String value) {
    var result = new _ContentType._();
    result._parse(value, ";");
    int index = result._value.indexOf("/");
    if (index == -1 || index == (result._value.length - 1)) {
      result._primaryType = result._value.trim().toLowerCase();
      result._subType = "";
    } else {
      result._primaryType =
          result._value.substring(0, index).trim().toLowerCase();
      result._subType = result._value.substring(index + 1).trim().toLowerCase();
    }
    return result;
  }

  String get mimeType => '$primaryType/$subType';

  String get primaryType => _primaryType;

  String get subType => _subType;

  String get charset => parameters["charset"];
}

class _Cookie implements Cookie {
  _Cookie([String this.name, String this.value]);

  _Cookie.fromSetCookieValue(String value) {
    // Parse the 'set-cookie' header value.
    _parseSetCookieValue(value);
  }

  // Parse a 'set-cookie' header value according to the rules in RFC 6265.
  void _parseSetCookieValue(String s) {
    int index = 0;

    bool done() => index == s.length;

    String parseName() {
      int start = index;
      while (!done()) {
        if (s[index] == "=") break;
        index++;
      }
      return s.substring(start, index).trim();
    }

    String parseValue() {
      int start = index;
      while (!done()) {
        if (s[index] == ";") break;
        index++;
      }
      return s.substring(start, index).trim();
    }

    void expect(String expected) {
      if (done()) throw new HttpException("Failed to parse header value [$s]");
      if (s[index] != expected) {
        throw new HttpException("Failed to parse header value [$s]");
      }
      index++;
    }

    void parseAttributes() {
      String parseAttributeName() {
        int start = index;
        while (!done()) {
          if (s[index] == "=" || s[index] == ";") break;
          index++;
        }
        return s.substring(start, index).trim().toLowerCase();
      }

      String parseAttributeValue() {
        int start = index;
        while (!done()) {
          if (s[index] == ";") break;
          index++;
        }
        return s.substring(start, index).trim().toLowerCase();
      }

      while (!done()) {
        String name = parseAttributeName();
        String value = "";
        if (!done() && s[index] == "=") {
          index++;  // Skip the = character.
          value = parseAttributeValue();
        }
        if (name == "expires") {
          expires = HttpDate._parseCookieDate(value);
        } else if (name == "max-age") {
          maxAge = int.parse(value);
        } else if (name == "domain") {
          domain = value;
        } else if (name == "path") {
          path = value;
        } else if (name == "httponly") {
          httpOnly = true;
        } else if (name == "secure") {
          secure = true;
        }
        if (!done()) index++;  // Skip the ; character
      }
    }

    name = parseName();
    if (done() || name.length == 0) {
      throw new HttpException("Failed to parse header value [$s]");
    }
    index++;  // Skip the = character.
    value = parseValue();
    if (done()) return;
    index++;  // Skip the ; character.
    parseAttributes();
  }

  String toString() {
    StringBuffer sb = new StringBuffer();
    sb.write(name);
    sb.write("=");
    sb.write(value);
    if (expires != null) {
      sb.write("; Expires=");
      sb.write(HttpDate.format(expires));
    }
    if (maxAge != null) {
      sb.write("; Max-Age=");
      sb.write(maxAge);
    }
    if (domain != null) {
      sb.write("; Domain=");
      sb.write(domain);
    }
    if (path != null) {
      sb.write("; Path=");
      sb.write(path);
    }
    if (secure) sb.write("; Secure");
    if (httpOnly) sb.write("; HttpOnly");
    return sb.toString();
  }

  String name;
  String value;
  DateTime expires;
  int maxAge;
  String domain;
  String path;
  bool httpOnly = false;
  bool secure = false;
}

class _UnmodifiableMap<K, V> implements Map<K, V> {
  final Map _map;
  const _UnmodifiableMap(this._map);

  bool containsValue(Object value) => _map.containsValue(value);
  bool containsKey(Object key) => _map.containsKey(key);
  V operator [](Object key) => _map[key];
  void operator []=(K key, V value) {
    throw new UnsupportedError("Cannot modify an unmodifiable map");
  }
  V putIfAbsent(K key, V ifAbsent()) {
    throw new UnsupportedError("Cannot modify an unmodifiable map");
  }
  addAll(Map other) {
    throw new UnsupportedError("Cannot modify an unmodifiable map");
  }
  V remove(Object key) {
    throw new UnsupportedError("Cannot modify an unmodifiable map");
  }
  void clear() {
    throw new UnsupportedError("Cannot modify an unmodifiable map");
  }
  void forEach(void f(K key, V value)) => _map.forEach(f);
  Iterable<K> get keys => _map.keys;
  Iterable<V> get values => _map.values;
  int get length => _map.length;
  bool get isEmpty => _map.isEmpty;
  bool get isNotEmpty => _map.isNotEmpty;
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
