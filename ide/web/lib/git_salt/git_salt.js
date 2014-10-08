// Copyright (c) 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

var fs;
var dir;

function onRead(entries) {
  console.log(entries);
}

function fsLoaded(fileSystem) {
  fs = fileSystem;
  console.log("file system loaded");
  var reader = fs.root.createReader();
  reader.readEntries(onRead);
}

window.webkitRequestFileSystem(window.PERSISTENT, 5 * 1024 * 1024 * 1024, fsLoaded);

function moduleDidLoad() {
  common.hideModule();
}

// Called by the common.js module.
function domContentLoaded(name, tc, config, width, height) {
  navigator.webkitPersistentStorage.requestQuota(1024 * 1024,
    function(bytes) {
      common.updateStatus(
          'Allocated ' + bytes + ' bytes of persistant storage.');
      common.attachDefaultListeners();
      common.createNaClModule(name, tc, config, width, height);
    },
    function(e) { alert('Failed to allocate space') });
}

// Called by the common.js module.
function attachListeners() {
  return;
}

function makeMessage(command, path) {
  // Package a message using a simple protocol containing:
  // command <path length> <path> <space-separated extra args>
  var msg = command;
  msg += ' ';
  msg += path.length;
  msg += ' ';
  msg += path;
  // Maybe add extra args
  for (var i = 2; i < arguments.length; ++i) {
    msg += ' ' + arguments[i];
  }
  return msg;
}

function saveFile() {
  if (common.naclModule) {
    common.naclModule.postMessage(makeMessage('sv', "/filename.txt", "some text"));
  }
}

// Called by the common.js module.
function handleMessage(message_event) {
console.log(message_event);  
var msg = message_event.data;
  var parts = msg.split('|');
  var command = parts[0];
  var args = parts.slice(1);

  if (command == 'ERR') {
    common.logMessage('Error: ' + args[0]);
  } else if (command == 'STAT') {
    common.logMessage(args[0]);
  } else if (command == 'READY') {
    common.logMessage('Filesystem ready!');
  } else if (command == 'DISP') {
    // Find the file editor that is currently visible.
    var fileEditorEl =
        document.querySelector('.function:not([hidden]) > textarea');
    // Rejoin args with pipe (|) -- there is only one argument, and it can
    // contain the pipe character.
    fileEditorEl.value = args.join('|');
  } else if (command == 'LIST') {
    var listDirOutputEl = document.getElementById('listDirOutput');

    // NOTE: files with | in their names will be incorrectly split. Fixing this
    // is left as an exercise for the reader.

    // Remove all children of this element...
    while (listDirOutputEl.firstChild) {
      listDirOutputEl.removeChild(listDirOutputEl.firstChild);
    }

    if (args.length) {
      // Add new <li> elements for each file.
      for (var i = 0; i < args.length; ++i) {
        var itemEl = document.createElement('li');
        itemEl.textContent = args[i];
        listDirOutputEl.appendChild(itemEl);
      }
    } else {
      var itemEl = document.createElement('li');
      itemEl.textContent = '<empty directory>';
      listDirOutputEl.appendChild(itemEl);
    }
  }
}
