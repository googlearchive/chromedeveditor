// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:io';

void main(List<String> arguments) {
  int port = arguments.isNotEmpty ? int.parse(arguments[0]) : 8080;;
  _run(port);
}

void _sendNotFound(HttpResponse response) {
  response.statusCode = HttpStatus.NOT_FOUND;
  response.close();
}

String _getHomePath() {
  final String path = Platform.script.toFilePath();
  final int index = path.lastIndexOf(Platform.pathSeparator);
  // For now, home path is spark/widgets/examples/.
  return path.substring(0, index + 1) + '..';
}

void _run(int port) {
  HttpServer.bind('127.0.0.1', port).then((HttpServer server) {
    print("Open Dartium with http://127.0.0.1:${port}");
    print("Server listening..");
    server.listen((HttpRequest request) {
      final String homeDirectory = _getHomePath();
      final String requestedPath = request.uri.toFilePath();
      final String resultPath = requestedPath == Platform.pathSeparator ?
          '${homeDirectory}${Platform.pathSeparator}index.html' :
          '${homeDirectory}${Platform.pathSeparator}${requestedPath}';
      final File file = new File(resultPath);
      file.exists().then((bool found) {
        if (found) {
          file.openRead()
              .pipe(request.response)
              .catchError((e) {
                request.response.write(e.toString());
                request.response.close();
              });
        } else {
          _sendNotFound(request.response);
        }
      });
    });
  });
}
