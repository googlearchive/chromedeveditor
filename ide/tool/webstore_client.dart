// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library webstore_client;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

class WebStoreClient {
  String _token;
  // Client ID of the application registered on Google Console.
  final String _clientID;
  // Client Secret of the application registered on Google Console.
  final String _clientSecret;
  // Refresh Token of the application registered on Google Console.
  final String _refreshToken;
  final String _appID;

  WebStoreClient(this._appID,
                 this._clientID,
                 this._clientSecret,
                 this._refreshToken);

  Future requestToken() {
    HttpClient client = new HttpClient();
    return client.postUrl(Uri.parse("https://accounts.google.com/o/oauth2/token"))
        .then((HttpClientRequest request) {
          request.headers.contentType
              = new ContentType("application", "x-www-form-urlencoded");
          String postData = 'client_id=${Uri.encodeQueryComponent(_clientID)}&client_secret=${Uri.encodeQueryComponent(_clientSecret)}&refresh_token=${Uri.encodeQueryComponent(_refreshToken)}&grant_type=refresh_token';
          request.headers.contentLength = postData.length;
          request.headers.set('Accept', '*/*');
          request.write(postData);
          return request.close();
        })
        .then((HttpClientResponse response) {
          Completer completer = new Completer();
          String result = '';
          response.listen((List<int> data) {
            String str = new String.fromCharCodes(data);
            result += str;
          }, onError: (e) {
            completer.completeError('Connection to server closed unexpectedly');
          }, onDone: () {
            Map<String, String> response = JSON.decode(result) as Map<String, String>;
            _token = response['access_token'];
            if (_token == null) {
              completer.completeError('authentication error');
            } else {
              completer.complete();
            }
          });

          return completer.future;
        });
  }

  Future uploadItem(String filename) {
    File file = new File(filename);
    List<int> data = file.readAsBytesSync();
  
    HttpClient client = new HttpClient();
    return client.openUrl('PUT', Uri.parse("https://www.googleapis.com/upload/chromewebstore/v1.1/items/${_appID}"))
        .then((HttpClientRequest request) {
          request.headers.contentType
              = new ContentType("application", "zip");
          request.headers.contentLength = data.length;
          request.headers.set('Accept', '*/*');
          request.headers.set('x-goog-api-version', '2');
          request.headers.set('Authorization', 'Bearer ${_token}');
          request.add(data);
          return request.close();
        })
        .then((HttpClientResponse response) {
          Completer completer = new Completer();
          String result = '';
          response.listen((List<int> data) {
            String str = new String.fromCharCodes(data);
            result += str;
          }, onError: (e) {
            completer.completeError('Connection to server closed unexpectedly');
          }, onDone: () {
            completer.complete(result);
          });

          return completer.future;
        });
  }

  Future publishItem() {
    HttpClient client = new HttpClient();
    return client.postUrl(Uri.parse("https://www.googleapis.com/upload/chromewebstore/v1.1/items/${_appID}/publish"))
        .then((HttpClientRequest request) {
          request.headers.contentType = 'application/json';
          request.headers.contentLength = 2;
          request.headers.set('Accept', '*/*');
          request.headers.set('x-goog-api-version', '2');
          request.headers.set('Authorization', 'Bearer ${_token}');
          request.write('{}');
          return request.close();
        })
        .then((HttpClientResponse response) {
          Completer completer = new Completer();
          String result = '';
          response.listen((List<int> data) {
            String str = new String.fromCharCodes(data);
            result += str;
          }, onError: (e) {
            completer.completeError('Connection to server closed unexpectedly');
          }, onDone: () {
            completer.complete(result);
          });

          return completer.future;
        });
  }
}