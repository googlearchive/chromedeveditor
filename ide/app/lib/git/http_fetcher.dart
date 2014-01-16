// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.http_fetcher;

import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:html';
import 'dart:typed_data';

import 'package:chrome/chrome_app.dart' as chrome;

import 'objectstore.dart';
import 'upload_pack_parser.dart';

final int COMMIT_LIMIT = 32;

class RefPath {
  String name;
  String sha;
  String head;

  RefPath(this.name, this.sha, this.head);

  getPktLine() => '${sha} ${head} ${name}';

  toString() => getPktLine();
}

/**
 *
 * TODO(grv) : Add unittests.
 */
class HttpFetcher {
  ObjectStore store;
  String name;
  String repoUrl;
  String username;
  String password;
  String url;
  Map<String, String> urlOptions = {};

  Map<String, GitRef> refs = {};

  HttpFetcher(this.store, this.name, this.repoUrl, [this.username,
      this.password]) {
    url = _getUrl(repoUrl);
    urlOptions = _queryParams(repoUrl);
  }

  GitRef getRef(String name) => refs[this.name + "/" + name];

  List<GitRef> getRefs() => refs.values;

  Future<List<GitRef>> fetchReceiveRefs() => _fetchRefs('git-receive-pack');

  Future<List<GitRef>> fetchUploadRefs() => _fetchRefs('git-upload-pack');

  Future pushRefs(List<RefPath> refPaths, chrome.ArrayBuffer packData,
      progress) {
    Completer completer = new Completer();
    String url = _makeUri('/git-receive-pack', {});
    Blob body = _pushRequest(refPaths, packData);
    HttpRequest xhr = getNewHttpRequest();
    xhr.open("POST", url, async: true , user: username , password: password);
    xhr.onLoad.listen((event) {
      if (xhr.readyState == 4) {
        if (xhr.status == 200) {
          String msg = xhr.response;
          if (msg.indexOf('000eunpack ok') == 0) {
            return completer.complete();
          } else {
            //TODO better error handling.
            throw "unpack error";
          }
        } else {
          _ajaxErrorHandler({"url": url, "type": "POST"}, xhr);
        }
      }
    });

    xhr.setRequestHeader('Content-Type',
        'application/x-git-receive-pack-request');
    String bodySize = (body.size / 1024).toStringAsFixed(2);
    xhr.upload.onProgress.listen((event) {
      // TODO add progress.
      progress();
    });
    xhr.send(body);
    return completer.future;
  }

  Future<PackParseResult> fetchRef(List<String> wantRefs,
      List<String> haveRefs, String shallow, int depth, List<String> moreHaves,
      noCommon, Function progress) {
    Completer completer = new Completer();
    String url = _makeUri('/git-upload-pack', {});
    String body = _refWantRequst(wantRefs, haveRefs, shallow, depth, moreHaves);
    HttpRequest xhr = getNewHttpRequest();

    //TODO add progress.
    Function packProgress, receiveProgress;

    xhr.open("POST", url, async: true , user: username , password: password);
    xhr.responseType = 'arraybuffer';
    xhr.setRequestHeader('Content-Type', 'application/x-git-upload-pack-request');

    xhr.onLoad.listen((event) {
      ByteBuffer buffer = xhr.response;
      if (haveRefs != null) {
        Uint8List data = new Uint8List.view(buffer, 4, 3);
        if (moreHaves.isNotEmpty && UTF8.decode(data.toList()) == "NAK") {
          //TODO handle case of more haves.
          //store.getCommitGraph(headShas, COMMIT_LIMIT).then((obj) {
          //});
        } else if (noCommon) {
          noCommon();
        }
      } else {

        if (packProgress != null) {
          packProgress({'pct': 0, 'msg': "Parsing pack data"});
        }

        // TODO add UploadPackParser class.
        UploadPackParser parser = getUploadPackParser();
        parser.parse(buffer, store, packProgress).then((PackParseResult obj) {
           completer.complete(obj);
        });
      }
    });

    xhr.onError.listen((_) => _ajaxErrorHandler({'url': url, 'type': 'POST'},
        xhr));

    xhr.onAbort.listen((_) => _ajaxErrorHandler({'url': url, 'type': 'POST'},
        xhr));

    xhr.send(body);
    return completer.future;
  }

  /*
   * Get a new instance of uploadPackParser. Exposed for tests to inject fake parser.
   */
  UploadPackParser getUploadPackParser() => new UploadPackParser();

  /*
   * Get a new instance of HttpRequest. Exposed for tests to inject fake xhr.
   */
  HttpRequest getNewHttpRequest() => new HttpRequest();

  /**
   * Parses the uri and returns the query params map.
   */
  Map<String, String> _queryParams(String uri) {
    List<String> parts = uri.split('?');
    if (parts.length < 2) return {};

    String queryString = parts[1];

    List<String> paramStrings = queryString.split("&");
    Map params = {};
    paramStrings.forEach((String paramStrimg) {
      List<String> pair = paramStrimg.split("=");
      params[pair[0] = Uri.decodeQueryComponent(pair[1])];
    });
    return params;
  }

  /**
   * Constructs and calls a http get request
   */
  Future<String> _doGet(String url) {
    Completer completer = new Completer();
    HttpRequest xhr = getNewHttpRequest();
    xhr.open("GET", url, async: true , user: username , password: password );

    xhr.onLoad.listen((event) {
      if (xhr.readyState == 4) {
        if (xhr.status == 200) {
          return completer.complete(xhr.responseText);
        } else {
          _ajaxErrorHandler({'url': url, 'type': 'GET'}, xhr);
        }
      }
    });

    xhr.onError.listen((_) => _ajaxErrorHandler({'url': url, 'type': 'GET'},
        xhr));
    xhr.onAbort.listen((_) => _ajaxErrorHandler({'url': url, 'type': 'GET'},
        xhr));
    xhr.send();
    return completer.future;
  }

  String _makeUri(String path, Map<String, String> extraOptions) {
    String uri = url + path;
    Map<String, String> options = urlOptions;
    options.addAll(extraOptions);
    if (options.isNotEmpty) {
      List<String> keys = options.keys;
      List<String> optionStrings = keys.map((String key) {
        return key + "=" + Uri.encodeQueryComponent(options[key]);
      });
      return uri + "?" + optionStrings.join("&");
    }
    return uri;
  }

  _ajaxErrorHandler(obj, xhr) {
    // TODO implement.
    throw "to be implemented.";
  }

  String _getUrl(String url) => repoUrl.replaceAll("\?.*", "").replaceAll(
      "\/\$", "");

  Map _parseDiscovery(String data) {
    List<String> lines = data.split("\n");
    List<GitRef> refs = [];
    Map result = {"refs" : refs};

    for (int i = 1; i < lines.length - 1; ++i) {
      String currentLine = lines[i];
      if (i == 1) {
        List<String> bits = currentLine.split("\u0000");
        result["capabilities"] = bits[1];
        List<String> bits2 = bits[0].split(" ");
        result["refs"].add(new GitRef(bits2[0].substring(8), bits2[1]));
      } else {
        List<String> bits2 = currentLine.split(" ");
        result["refs"].add(new GitRef(bits2[0].substring(4), bits2[1]));
      }
    }
    return result;
  }

  String _padWithZeros(int num) {
    String hex = num.toRadixString(16);
    int pad = 4 - hex.length;
    for (int i = 0; i < pad; ++i) {
      hex = '0' + hex;
    }
    return hex;
  }

  Blob _pushRequest(List<RefPath> refPaths, chrome.ArrayBuffer packData) {
    List blobParts = [];
    String header = refPaths[0].getPktLine() + '\0report-status\n';
    header = _padWithZeros(header.length + 4) + header;
    blobParts.add(header);

    for (int i = 1; i < refPaths.length; ++i) {
      if (refPaths[i].head == null) continue;
      String val = refPaths[i].getPktLine() + '\n';
      blobParts.add(_padWithZeros(val.length + 4));
    }

    blobParts.add('0000');
    blobParts.add(new Uint8List.fromList(packData.getBytes()));
    return new Blob(blobParts);
  }

  /**
   * Constructs a want request from the server.
   */
  String _refWantRequst(List<String> wantRefs, List<String> haveRefs, String shallow,
      int depth, List<String> moreHaves) {
    StringBuffer request = new StringBuffer("0067want ${wantRefs[0]} ");
    request.write("multi_ack_detailed side-band-64k thin-pack ofs-delta\n");
    for (int i = 1; i < wantRefs.length; ++i) {
      request.write("0032want ${wantRefs[i]}\n");
    }

    if (haveRefs != null) {
      if (shallow != null) {
        request.write("0034shallow " + shallow);
      }
      request.write("0000");
      haveRefs.forEach((String sha) {
        request.write("0032have ${sha}\n");
      });
      if (moreHaves.isNotEmpty) {
        request.write("0000");
      } else {
        request.write("0009done\n");
      }
    } else {
      if (depth != null) {
        String depthStr = "deepen ${depth}";
        request.write((_padWithZeros(depthStr.length + 4) + depthStr));
      }
      request.write("0000");
      request.write("0009done\n");
    }
    return request.toString();
  }

  _addRef(GitRef ref) {
    String type;
    String name;
    if (ref.name.length > 5 && ref.name.substring(0,5) == "refs/") {
      type = ref.name.split("/")[1];
      name = this.name + "/" + ref.name.split("/")[2];
    } else {
      type = "HEAD";
      name = this.name + "/HEAD";
    }

    refs[name] = new GitRef(ref.sha, name, type, this);
  }

  Future<List<GitRef>> _fetchRefs(String service) {
    String uri = _makeUri('/info/refs', {"service": service});
    return _doGet(uri).then((String data) {
      Map discInfo = _parseDiscovery(data);
      discInfo["refs"].forEach((GitRef ref) => _addRef(ref));
      return new Future.value(discInfo["refs"]);
    });
  }
}
