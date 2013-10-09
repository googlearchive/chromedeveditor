
library git;

import 'dart:async';
import 'dart:js' as js;

class GitResult {
  var result;
  GitResult.fromData(this.result);
}

class Git {

  static final js.JsObject _jsgit = js.context['GitApi'];

  Git() {
    print('Git Api initialized.');
  }

  Future<GitResult> clone(options) {
    return _apiCall('clone', options);
  }

  Future<GitResult> push(options) {
    return _apiCall('push', options);
  }

  Future<GitResult> pull(options) {
    return _apiCall('pull', options);
  }

  Future<GitResult> commit(options) {
    return _apiCall('commit', options);
  }

  Future<GitResult> branch(options) {
    return _apiCall('branch', options);
  }

  Future<GitResult> checkout(options) {
    return _apiCall('checkout', options);
  }

  Future<GitResult> checkForUncommittedChanges(options) {
    return _apiCall('checkForUncommittedChanges', options);
  }

  Future<GitResult> getCurrentBranch(options) {
    return _apiCall('getCurrentBranch', options);
  }

  Future<GitResult> getLocalBranches(options) {
    return _apiCall('getLocalBranches', options);
  }

  Future<GitResult> getRemoteBranches(options) {
    return _apiCall('getRemoteBranches', options);
  }

  Future<GitResult> _apiCall(String functionName, options) {
    Completer<GitResult> completer = new Completer();

    var successCallback = (result) {
       completer.complete(new GitResult.fromData(result));
    };

    var errorCallback = (String message) {
      completer.completeError(message);
    };

    _jsgit.callMethod(functionName,[options, successCallback, errorCallback]);

    return completer.future;
  }

}
