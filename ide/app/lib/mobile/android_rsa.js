// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A library to manage Android RSA key generation and signature.
 * It's a wrapper on the of the NaCL Android RSA module.
 *
 * Here's the error codes that can be returned:
 *
 * invalid_parameters
 * When the number of parameters is not correct.
 *
 * invalid_parameters_types:
 * When a parameter has an invalid type.
 *
 * unknown_command:
 * The command is unknown.
 *
 * unexpected:
 * Unexpected error: generally happens a memory error happens
 *
 * invalid_key:
 * Invalid private key.
 *
 * empty_input
 * Invalid or empty input.
 */

var AndroidRSA = {};

/*
  All commands will be stored in a queue. The queue will start being processed
  once the NaCL module is loaded.

  Each command will be assigned a UUID. An internal callback will take care of
  both error and success case. This callback will be stored in a hash map.
*/

// The queue of commands.
AndroidRSA._queue = [];

// It's the callback when returning from the NaCL module.
// uuid -> function.
AndroidRSA._callbacks = {};

// It's a reference to the NaCL module.
AndroidRSA._module = null;

// This method is called when the NaCL module is loaded.
AndroidRSA._moduleDidLoad = function() {
  AndroidRSA._module = document.getElementById('android-rsa');
  AndroidRSA._queueConsume();
}

// This method is called when a message is received from the NaCL module.
AndroidRSA._handleMessage = function(messageEvent) {
  if (messageEvent.data === null) {
    console.log('null message, ignore');
    console.log(messageEvent.data);
    return;
  }
  if (typeof messageEvent.data !== 'object') {
    console.log('invalid message, ignore');
    console.log(messageEvent.data);
    return;
  }

  if (messageEvent.data.log != null) {
    console.log(messageEvent.data.log);
    return;
  }
  if (messageEvent.data.uuid == null) {
    console.log('invalid message, missing UUID');
    console.log(messageEvent.data);
    return;
  }

  // Call the callback related to this command.
  var callback = AndroidRSA._callbacks[messageEvent.data.uuid];
  if (callback != null) {
    delete AndroidRSA._callbacks[messageEvent.data.uuid];
    callback(messageEvent.data);
  }
}

// Queues a command.
AndroidRSA._runCommand = function(command, parameters, callback) {
  var uuid = UUID.generate();
  var item = {'uuid': uuid, 'command': command, 'parameters': parameters};

  // Store the callback.
  AndroidRSA._callbacks[uuid] = callback;

  AndroidRSA._queueAddItem(item);
  AndroidRSA._queueConsume();
}

// Adds an command to the command queue.
AndroidRSA._queueAddItem = function(item) {
  AndroidRSA._queue.push(item);
}

// Consume the queue of commands.
AndroidRSA._queueConsume = function() {
  if (AndroidRSA._module == null) {
    return;
  }
  
  AndroidRSA._queue.forEach(function(item) {
    AndroidRSA._module.postMessage(item);
  });
  AndroidRSA._queue = [];
}

/**
 * AndroidRSA.generateKey(function callback, function error_handler)
 * 
 * Returns a generated private key.
 * 
 * AndroidRSA.generateKey(function(string privateKey) {
 *   // Do something.
 * }, function(error_code) {
 *   console.log('got error: ' + error_code);
 * });
 */
AndroidRSA.generateKey = function(callback, error_handler) {
  AndroidRSA._runCommand('generate_key', [], function(data) {
    if (data.error != null) {
      if (error_handler != null) {
        error_handler(data.error);
      }
    } else {
      if (callback != null) {
        callback(data.result);
      }
    }
  });
}

/**
 * AndroidRSA.sign(string key, UInt8Array buffer, function callback, function error_handler)
 * 
 * Returns the signature of the buffer using the given key.
 * 
 * AndroidRSA.sign(privatekey, buffer, function(signature) {
 *   sendSignatureOverTheWire(signature, ...);
 * }, function(error_code) {
 *   console.log('got error: ' + error_code);
 * });
 */
AndroidRSA.sign = function(key, buffer, callback, error_handler) {
  AndroidRSA._runCommand('sign', [key, buffer], function(data) {
    if (data.error != null) {
      if (error_handler != null) {
        error_handler(data.error);
      }
    } else {
      if (callback != null) {
        callback(data.result);
      }
    }
  });
}

/**
 * AndroidRSA.getPublicKey(string privatekey, function callback, function error_handler)
 * 
 * Returns the public key in a format used in the ADB protocol.
 * 
 * AndroidRSA.getPublicKey(privatekey, function(publickey) {
 *   sendKeyOverTheWire(publickey, ...);
 * }, function(error_code) {
 *   console.log('got error: ' + error_code);
 * });
 */
AndroidRSA.getPublicKey = function(key, callback, error_handler) {
  AndroidRSA._runCommand('get_public_key', [key], function(data) {
    if (data.error != null) {
      if (error_handler != null) {
        error_handler(data.error);
      }
    } else {
      if (callback != null) {
        callback(data.result);
      }
    }
  });
}

/**
 * AndroidRSA.randomSeed(UInt8Array buffer, function callback, function error_handler)
 * 
 * Seeds the pseudo random number generator with some unpredictable data (buffer).
 * 
 * AndroidRSA.randomSeed(buffer, function() {
 *   console.log('random seed done');
 * }, function(error_code) {
 *   console.log('got error: ' + error_code);
 * })
 */
AndroidRSA.randomSeed = function(buffer, callback, error_handler) {
  AndroidRSA._runCommand('random_seed', [buffer], function(data) {
    if (data.error != null) {
      if (error_handler != null) {
        error_handler(data.error);
      }
    } else {
      if (callback != null) {
        callback();
      }
    }
  });
}

// Registers handler for NaCL module loading and callbacks.
AndroidRSA._register = function() {
  var container = document.getElementById('android-rsa-container');
  container.addEventListener('load', AndroidRSA._moduleDidLoad, true);
  container.addEventListener('message', AndroidRSA._handleMessage, true);
}

AndroidRSA._register();
