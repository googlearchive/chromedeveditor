// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

'use strict';

var WamFS = function() {
  // Our in-memory wam-ready file system.
  this.jsfs = new wam.jsfs.FileSystem();
}

WamFS.prototype.connect = function(extensionID, mountPath, onSuccess, onError) {
  // Reflect our DOM file system into the wam file system.
  this.jsfs.makeEntry('/domfs', new wam.jsfs.dom.FileSystem(),
                      function() {
                        this._mount(extensionID, mountPath, onSuccess, onError)
                      }.bind(this),
                      function(e) {
                        onError(e);
                      });
};

WamFS.prototype._mount = function(id, path, onSuccess, onError) {
  // wam remote file system object.
  var rfs = null;

  // Called when the remote file system becomes ready.
  var onFileSystemReady = function() {
    // Now that it's ready we can remove our initial listeners.  These
    // were only intended to cover the initial ready or close-with-error
    // conditions.  A longer term onClose listener should be installed to
    // check for unexpected loss of the file system.
    rfs.onReady.removeListener(onFileSystemReady);
    rfs.onClose.removeListener(onFileSystemClose);

    // Link the remote file system into our root file system under the given
    // path.
    this.jsfs.makeEntry(path, rfs, function() {
                         onSuccess();
                        }, function(value) {
                          transport.disconnect();
                          onError(value);
                        });
  }.bind(this);

  // Called when the remote file system gets closed.
  var onFileSystemClose = function(value) {
    rfs.onReady.removeListener(onFileSystemReady);
    rfs.onClose.removeListener(onFileSystemClose);

    onError(value);
  };

  // Connection failed at the transport level.  The target app probably isn't
  // installed or isn't willing to acknowledge us.
  var onTransportClose = function(reason, value) {
    transport.readyBinding.onClose.removeListener(onTransportClose);
    transport.readyBinding.onReady.removeListener(onTransportReady);

    onError(wam.mkerr('wam.FileSystem.Error.RuntimeError',
                      ['Transport connection failed.']));
    return;
  };

  // The target app accepted our connection request, now we've got to negotiate
  // a wam channel.
  var onTransportReady = function(reason, value) {
    transport.readyBinding.onClose.removeListener(onTransportClose);
    transport.readyBinding.onReady.removeListener(onTransportReady);

    var channel = new wam.Channel(transport, 'crx:' + id);
    // Uncomment the next line for verbose logging.
    // channel.verbose = wam.Channel.verbosity.ALL;
    rfs = new wam.jsfs.RemoteFileSystem(channel);
    rfs.onReady.addListener(onFileSystemReady);
    rfs.onClose.addListener(onFileSystemClose);
  };

  // Create a new chrome.runtime.connect based transport.
  var transport = new wam.transport.ChromePort();

  // Register our close and ready handlers.
  transport.readyBinding.onClose.addListener(onTransportClose);
  transport.readyBinding.onReady.addListener(onTransportReady);

  // Connect to the target extension/app id.
  transport.connect(id);
};

WamFS.prototype.copyFile = function(source, destination, onSuccess, onError) {
  this.jsfs.defaultBinding.copyFile(source, destination,
                                    function() {
                                      onSuccess();
                                    }, function(e) {
                                      onError(e);
                                    });
};

WamFS.prototype.readFile = function(filename, onSuccess, onError) {
  this.jsfs.defaultBinding.readFile(filename,
                                    function() {
                                      onSuccess();
                                    }, function(e) {
                                      onError(e);
                                    });
};

WamFS.prototype.writeDataToFile = function(filename, content, onSuccess, onError) {
  this.jsfs.defaultBinding.writeFile(filename,
                                     {mode: {create: true}},
                                     {dataType: 'arraybuffer', data: content},
                                     function() {
                                       onSuccess();
                                     }, function(e) {
                                       onError();
                                     });
};

WamFS.prototype.writeStringToFile = function(filename, stringContent, onSuccess, onError) {
  this.jsfs.defaultBinding.writeFile(filename,
                                     {mode: {create: true}},
                                     {dataType: 'utf8-string', data: stringContent},
                                     function() {
                                       onSuccess();
                                     }, function(e) {
                                       onError(e);
                                     });
};

WamFS.prototype.executeCommand = function(executablePath, parameters,
      printStdout, printStderr, onSuccess, onError) {
  var executeContext = this.jsfs.defaultBinding.createExecuteContext();
  executeContext.onStdOut.addListener(function(l) {
    printStdout(l);
  });
  executeContext.onStdErr.addListener(function(l) {
    printStderr(l);
  });
  executeContext.onClose.addListener(function() {
    onSuccess();
  });
  executeContext.execute(executablePath, parameters);
}
