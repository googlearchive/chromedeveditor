/*
 * Copyright 2013 The Polymer Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 */

// if standalone
if (window.top === window) {
  // if standalone
  var failed = false;
  window.done = function() {
    window.onerror = null;
    if (!failed) {
      var d = document.createElement('pre');
      d.style.cssText = 'padding: 6px; background-color: lightgreen; position: absolute; bottom:0; right:10px;';
      d.textContent = 'Passed';
      document.body.appendChild(d);
    }
  };
  window.onerror = function(x) {
    failed = true;
    var d = document.createElement('pre');
    d.style.cssText = 'padding: 6px; background-color: #FFE0E0; position: absolute; bottom:0; right:10px;';
    d.textContent = 'FAILED: ' + x;
    document.body.appendChild(d);
  };
} else
// if part of a test suite
{
  window.done = function() {
    window.onerror = null;
    parent.postMessage('ok', '*');
  };
  
  window.onerror = function(x) {
    parent.postMessage({error: x}, '*');
  };
}

window.asyncSeries = function(series, callback, forwardExceptions) {
  series = series.slice();
  var next = function(err) {
    if (err) {
      if (callback) {
        callback(err);
      }
    } else {
      var f = series.shift();
      if (f) {
        if (!forwardExceptions) {
          f(next);
        } else {
          try {
            f(next);
          } catch(e) {
            if (callback) {
              callback(e);
            }
          }
        }
      } else {
        if (callback) {
          callback();
        }
      }
    }
  };
  next();
};

window.waitFor = function(fn, next, intervalOrMutationEl, timeout, timeoutTime) {
  timeoutTime = timeoutTime || Date.now() + (timeout || 1000);
  intervalOrMutationEl = intervalOrMutationEl || 32;
  try {
    fn(); 
  } catch (e) { 
    if (Date.now() > timeoutTime) {
      throw e;
    } else {
      if (isNaN(intervalOrMutationEl)) {
        intervalOrMutationEl.onMutation(intervalOrMutationEl, function() {
          waitFor(fn, next, intervalOrMutationEl, timeout, timeoutTime);
        });
      } else {
        setTimeout(function() {
          waitFor(fn, next, intervalOrMutationEl, timeout, timeoutTime);
        }, intervalOrMutationEl);
      }
      return;
    }
  }
  next();
};
