// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
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
      return new Future.error("Could not authenticate.");
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
      Map responseMap = JSON.decode(request.response);
      if (identifier == null) {
        identifier = responseMap['id'];
      }
      bool success = (responseMap['uploadState'] == 'SUCCESS');
      if (!success) {
        String errorString = null;
        List<Map> errors = responseMap['itemError'];
        // We do defensive type checking here because it's coming from a webservice.
        if (errors is List) {
          for(var item in errors) {
            if (item is Map) {
              Map error = item;
              if ((errorString == null) && (error['error_detail'] is String)) {
                errorString = error['error_detail'];
              } else {
                errorString += '\n' + error['error_detail'];
              }
            }
          }
        }
        if (errorString == null) {
          errorString = "Upload to webstore failed";
        }
        completer.completeError(errorString);
      } else {
        completer.complete(identifier);
      }
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
