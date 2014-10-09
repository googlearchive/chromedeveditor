(function() {

  var files;
  var browserId;

  var socketEndpoint = window.location.protocol + '//' + window.location.host;
  var thisFile = 'ci-support.js';
  var thisScript = document.querySelector('script[src$="' + thisFile + '"]');
  var base = thisScript.src.substring(0, thisScript.src.lastIndexOf('/')+1);

  var tools = {
    'mocha-tdd': [
      base + 'mocha/mocha.css',
      base + 'mocha/mocha.js',
      base + 'mocha-htmltest.js',
      function() {
        var div = document.createElement('div');
        div.id = 'mocha';
        document.body.appendChild(div);
        mocha.setup({ui: 'tdd', slow: 1000, timeout: 10000, htmlbase: ''});
      }
    ],
    'chai': [
      base + 'chai/chai.js'
    ]
  };

  function addFile() {
    var file = files.shift();
    if (Object.prototype.toString.call(file) == '[object Function]') {
      file();
      nextFile();
    }
    else if (file.slice(-3) == '.js') {
      var script = document.createElement('script');
      script.src = file;
      script.onload = nextFile;
      script.onerror = function() { console.error('Could not load ' + script.src); };
      document.head.appendChild(script);
    } else if (file.slice(-4) == '.css') {
      var sheet = document.createElement('link');
      sheet.rel = 'stylesheet';
      sheet.href = file;
      document.head.appendChild(sheet);
      nextFile();
    }
  }

  function nextFile() {
    if (files.length) {
      addFile();
    } else {
      startMocha();
    }
  }

  function getQueryVariable(variable) {
    var query = window.location.search.substring(1);
    var vars = query.split("&");
    for (var i=0;i<vars.length;i++) {
      var pair = vars[i].split("=");
      if (pair[0] == variable) {
        return pair[1];
      }
    }
    return(false);
  }

  function runTests(setup) {
    browserId = getQueryVariable('browser');
    files = [];

    if (browserId) {
      files.push(socketEndpoint + '/socket.io/socket.io.js');
    }

    if (typeof setup == 'string') {
      var xhr = new XMLHttpRequest();
      xhr.open('GET', setup);
      xhr.responseType = 'application/json';
      xhr.send();
      xhr.onreadystatechange = function() {
        if (xhr.readyState == 4) {
          setupTests(JSON.parse(xhr.response));
        }
      };
    } else {
      setupTests(setup);
    }
  }

  function setupTests(setup) {
    if (setup.tools) {
      setup.tools.forEach(function(tool) {
        if (tools[tool]) {
          files = files.concat(tools[tool]);
        } else {
          console.error('Unknown tool: ' + tool);
        }
      });
    }
    if (setup.dependencies) {
      files = files.concat(setup.dependencies.map(function(d) {
        return '../' + d;
      }));
    }
    files = files.concat(setup.tests);
    nextFile();
  }

  function startMocha() {
    var runner = mocha.run();

    var socket;
    if (browserId) {
      socket = io(socketEndpoint);
    }

    var emitEvent = function(event, data) {
      var payload = {browserId: browserId, event: event, data: data};
      console.log('client-event:', payload);
      if (!socket) return;
      socket.emit('client-event', payload);
    };

    var getTitles = function(runnable) {
      var titles = [];
      while (runnable && runnable.title) {
        titles.unshift(runnable.title);
        runnable = runnable.parent;
      }
      return titles;
    };

    var getState = function(runnable) {
      if (runnable.state === 'passed') {
        return 'passing';
      } else if (runnable.state == 'failed') {
        return 'failing';
      } else if (runnable.pending) {
        return 'pending';
      } else {
        return 'unknown';
      }
    };

    var cleanError = function(error) {
      if (!error) return undefined;
      return {message: error.message, stack: error.stack};
    };

    // the runner's start event has already fired.
    emitEvent('browser-start', {
      total: runner.total,
      url:   window.location.toString(),
    });

    // We only emit a subset of events that we care about, and follow a more
    // general event format that is hopefully applicable to test runners beyond
    // mocha.
    //
    // For all possible mocha events, see:
    // https://github.com/visionmedia/mocha/blob/master/lib/runner.js#L36
    runner.on('test', function(test) {
      emitEvent('test-start', {test: getTitles(test)});
    });
    runner.on('test end', function(test) {
      emitEvent('test-end', {
        state:    getState(test),
        test:     getTitles(test),
        duration: test.duration,
        error:    cleanError(test.err),
      });
    });
    runner.on('end', function() {
      emitEvent('browser-end');
    });
  }

  window.runTests = runTests;
})();
