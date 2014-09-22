
  document.addEventListener('polymer-ready', function() {
    // setup
    var basic = document.querySelector('#basic');
    var overlay = document.querySelector('#overlay');
    var template = document.querySelector('template');

    function testWhenOpen(element, test, next) {
      var l1 = function() {
        test();
        element.async(function() {
          element.opened = false;
        }, 1);
      };
      var l2 = function() {
        element.removeEventListener('core-overlay-open-completed', l1);
        element.removeEventListener('core-overlay-close-completed', l2);
        next();
      };
      element.addEventListener('core-overlay-open-completed', l1);
      element.addEventListener('core-overlay-close-completed', l2);
      element.opened = true;
    }

    asyncSeries([
      // centered overlay
      function(next) {
        testWhenOpen(basic, function() {
          var rect = basic.getBoundingClientRect();
          chai.assert.ok(Math.abs(rect.left - (window.innerWidth - rect.right)) < 5, 'overlay centered horizontally');
          chai.assert.ok(Math.abs(rect.top - (window.innerHeight - rect.bottom)) < 5, 'overlay centered vertically');
        }, next);
      },
      // css positioned overlay
      function(next) {
        testWhenOpen(overlay, function() {
          var rect = overlay.getBoundingClientRect();
          chai.assert.equal(rect.left, 16, 'positions via css');
          chai.assert.equal(rect.top, 16, 'positions via css');
        }, next);
      },
      // manual positioned overlay
      function(next) {
        overlay.style.left = overlay.style.top = 'auto';
        overlay.style.right = '0px';
        testWhenOpen(overlay, function() {
          var rect = overlay.getBoundingClientRect();
          chai.assert.equal(rect.right, window.innerWidth - 16, 'positioned manually');
          chai.assert.ok(Math.abs(rect.top - (window.innerHeight - rect.bottom)) <= 16, 'overlay centered vertically');
        }, next);
      },
      // overflow, position top, left
      function(next) {
        overlay.style.left = overlay.style.top = '0px';
        overlay.style.right = 'auto';
        overlay.style.width = overlay.style.height = 'auto';
        for (var i=0; i<20; i++) {
          overlay.appendChild(template.content.cloneNode(true));  
        }
        testWhenOpen(overlay, function() {
          var rect = overlay.getBoundingClientRect();
          chai.assert.ok(window.innerWidth >= rect.right, 'overlay constrained to window size');
          chai.assert.ok(window.innerHeight >= rect.bottom, 'overlay constrained to window size');
        }, next);
      },
      // overflow, position, bottom, right
      function(next) {
        overlay.style.right = overlay.style.bottom = '0px';
        overlay.style.left = overlay.style.top = 'auto';
        testWhenOpen(overlay, function() {
          var rect = overlay.getBoundingClientRect();
          chai.assert.ok(window.innerWidth >= rect.right, 'overlay constrained to window size');
          chai.assert.ok(window.innerHeight >= rect.bottom, 'overlay constrained to window size');
        }, next);
      },
      // overflow, unpositioned
      function(next) {
        overlay.style.right = overlay.style.bottom = 'auto';
        overlay.style.left = overlay.style.top = 'auto';
        testWhenOpen(overlay, function() {
          var rect = overlay.getBoundingClientRect();
          chai.assert.ok(window.innerWidth >= rect.right, 'overlay constrained to window size');
          chai.assert.ok(window.innerHeight >= rect.bottom, 'overlay constrained to window size');
        }, next);
      },
      // overflow, unpositioned, layered
      function(next) {
        overlay.layered = true;
        testWhenOpen(overlay, function() {
          var rect = overlay.getBoundingClientRect();
          chai.assert.ok(window.innerWidth >= rect.right, 'overlay constrained to window size');
          chai.assert.ok(window.innerHeight >= rect.bottom, 'overlay constrained to window size');
        }, next);
      },
    ], done);
  });

