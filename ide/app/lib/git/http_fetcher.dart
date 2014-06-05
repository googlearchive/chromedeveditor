// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.http_fetcher;

import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:html';
import 'dart:typed_data';

import 'exception.dart';
import 'objectstore.dart';
import 'upload_pack_parser.dart';
import 'utils.dart';

final int COMMIT_LIMIT = 32;

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

  Future pushRefs(List<GitRef> refPaths, List<int> packData, progress) {
    Completer completer = new Completer();
    String url = _makeUri('/git-receive-pack', {});
    Blob body = _pushRequest(refPaths, packData);

    var xhr = getNewHttpRequest();
    xhr.open("POST", url, async: true , user: username, password: password);
    xhr.setRequestHeader('Content-Type', 'application/x-git-receive-pack-request');
    xhr.onLoad.listen((event) {
      if (xhr.readyState == 4) {
        if (xhr.status == 200) {
          String msg = xhr.response;
          if (msg.indexOf('000eunpack ok') == 0) {
            completer.complete();
          } else {
            //TODO better error handling.
            completer.completeError("unpack error");
          }
        } else {
          _ajaxErrorHandler({"url": url, "type": "POST"}, xhr);
        }
      }
    });
    xhr.onError.listen((_) => completer.completeError(HttpGitException.fromXhr(xhr)));
    String bodySize = (body.size / 1024).toStringAsFixed(2);
    xhr.upload.onProgress.listen((event) {
      // TODO add progress.
      if (progress != null) {
        progress();
      }
    });

    xhr.send(body);

    return completer.future;
  }

  Future<PackParseResult> fetchRef(List<String> wantRefs,
      List<String> haveRefs, String shallow, int depth, List<String> moreHaves,
      noCommon, Function progress, [Cancel cancel]) {
    Completer completer = new Completer();
    String url = _makeUri('/git-upload-pack', {});
    String body = _refWantRequst(wantRefs, haveRefs, shallow, depth, moreHaves);
    var xhr = getNewHttpRequest();

    //TODO add progress.
    Function packProgress, receiveProgress;

    xhr.open("POST", url, async: true , user: username , password: password);
    xhr.responseType = 'arraybuffer';
    xhr.setRequestHeader('Content-Type', 'application/x-git-upload-pack-request');

    xhr.onLoad.listen((event) {
      ByteBuffer buffer = xhr.response;
      Uint8List data = new Uint8List.view(buffer, 4, 3);
      if (haveRefs != null && UTF8.decode(data.toList()) == "NAK") {
        if (moreHaves.isNotEmpty) {
          //TODO handle case of more haves.
          //store.getCommitGraph(headShas, COMMIT_LIMIT).then((obj) {
          //});
        } else if (noCommon) {
          noCommon();
        }
        completer.completeError("error in git pull");
      } else {

        if (packProgress != null) {
          packProgress({'pct': 0, 'msg': "Parsing pack data"});
        }

        UploadPackParser parser = getUploadPackParser(cancel);
        return parser.parse(buffer, store, packProgress).then(
            (PackParseResult obj) {
           completer.complete(obj);
        }, onError: (e) {
          completer.completeError(e);
        });
      }
    });

    xhr.onError.listen((_) {
      completer.completeError(HttpGitException.fromXhr(xhr));
    });

    xhr.onAbort.listen((_) {
      completer.completeError(HttpGitException.fromXhr(xhr));
    });

    xhr.send(body);
    return completer.future;
  }

  /*
   * Get a new instance of uploadPackParser. Exposed for tests to inject fake parser.
   */
  UploadPackParser getUploadPackParser([Cancel cancel])
      => new UploadPackParser(cancel);

  /*
   * Get a new instance of HttpRequest. Exposed for tests to inject fake xhr.
   */
  getNewHttpRequest() => new HttpRequest();

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
    var xhr = getNewHttpRequest();
    xhr.open("GET", url, async: true , user: username , password: password );

    xhr.onLoad.listen((event) {
      if (xhr.readyState == 4) {
        if (xhr.status == 200) {
          return completer.complete(xhr.responseText);
        } else {
          completer.completeError(HttpGitException.fromXhr(xhr));
        }
      }
    });

    xhr.onError.listen((_) {
      completer.completeError(HttpGitException.fromXhr(xhr));
    });

    xhr.onAbort.listen((_) {
      completer.completeError(HttpGitException.fromXhr(xhr));
    });

    xhr.send();
    return completer.future;
  }

  /**
   * Some git repositories do not end with '.git' suffix. Validate those urls
   * by sending a request to the server.
   */
  Future<bool> isValidRepoUrl() {
    String uri = _makeUri('/info/refs', {"service": 'git-upload-pack'});
    try {
      return _doGet(uri).then((_) => true).catchError((e) {
        if (e.status == 401) {
          throw new GitException(GitErrorConstants.GIT_AUTH_REQUIRED);
        }
        return new Future.value(false);
      });
    } catch (e) {
      return new Future.value(false);
    }
  }

  String _makeUri(String path, Map<String, String> extraOptions) {
    String uri = url + path;
    Map<String, String> options = urlOptions;
    options.addAll(extraOptions);
    if (options.isNotEmpty) {
      Iterable<String> keys = options.keys;
      Iterable<String> optionStrings = keys.map((String key) {
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

  Blob _pushRequest(List<GitRef> refPaths, List<int> packData) {
    List blobParts = [];
    String header = refPaths[0].getPktLine() + '\u0000report-status\n';
    header = _padWithZeros(header.length + 4) + header;
    blobParts.add(header);

    for (int i = 1; i < refPaths.length; ++i) {
      if (refPaths[i].head == null) continue;
      String val = refPaths[i].getPktLine() + '\n';
      blobParts.add(_padWithZeros(val.length + 4));
    }

    blobParts.add('0000');
    blobParts.add(new Uint8List.fromList(packData));
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

class HttpGitException extends GitException {
  int status;
  String statusText;

  HttpGitException(this.status, this.statusText, [String errorCode,
      String message, bool canIgnore]) : super(errorCode, message, canIgnore);

  static fromXhr(HttpRequest request) {
    String errorCode;

    if (request.status == 401) {
      errorCode = GitErrorConstants.GIT_AUTH_ERROR;
    } else if (request.status == 404) {
        errorCode = GitErrorConstants.GIT_HTTP_404_ERROR;
    } else {
      errorCode = GitErrorConstants.GIT_HTTP_ERROR;
    }

    return new HttpGitException(request.status, request.statusText, errorCode,
        "", false);
  }

  /**
   * Returns `true` if the status is 401 Unauthorized.
   */
  bool get needsAuth => status == 401;

  String toString() => '${status} ${statusText}';
}
