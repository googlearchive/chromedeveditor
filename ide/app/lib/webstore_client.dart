// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.webstore_client;

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:html';

import 'package:chrome/chrome_app.dart' as chrome;

class WebStoreClient {
  String _token;

  // Authenticate against the Chrome Webstore.
  Future authenticate() {
    return chrome.identity.getAuthToken(new chrome.TokenDetails(interactive: true)).then((String token) {
      _token = token;
    }).catchError((e) {
      throw "Could not authenticate.";
    });
  }

  Future<String> uploadItem(List<int> data, {String identifier: null}) {
    Completer completer = new Completer();

    var request = new HttpRequest();
    if (identifier == null) {
      request.open('POST', 'https://www.googleapis.com/upload/chromewebstore/v1.1/items');
    } else {
      request.open('PUT', 'https://www.googleapis.com/upload/chromewebstore/v1.1/items/${identifier}');
    }
    request.responseType = '*/*';
    request.setRequestHeader('Authorization', 'Bearer ${_token}');
    request.setRequestHeader('x-goog-api-version', '2');
    request.onLoad.listen((event) {
      if (identifier == null) {
        Map responseMap = JSON.decode(request.response);
        identifier = responseMap['id'];
        bool success = (responseMap['uploadState'] == 'SUCCESS');
        if (!success) {
          throw "Upload to webstore failed";
        }
      }
      print('Request complete ${request.response}');
      completer.complete(identifier);
    });
    request.onError.listen((event) {
      completer.completeError("Upload to webstore failed: connection error");
    });
    request.send(data);

    return completer.future;
  }

  Future publish(String appid) {
    Completer completer = new Completer();

    var request = new HttpRequest();
    request.open('POST', 'https://www.googleapis.com/chromewebstore/v1.1/items/${appid}/publish');
    request.responseType = '*/*';
    request.setRequestHeader('Authorization', 'Bearer ${_token}');
    request.setRequestHeader('x-goog-api-version', '2');
    request.onLoad.listen((event) {
      Map responseMap = JSON.decode(request.response);
      bool success = (responseMap['error'] == null);
      if (!success) {
        completer.completeError("Publish to webstore failed");
      }
      completer.complete();
    });
    request.onError.listen((event) {
      completer.completeError("Publish to webstore: connection error");
    });
    request.send();

    return completer.future;
  }
}
