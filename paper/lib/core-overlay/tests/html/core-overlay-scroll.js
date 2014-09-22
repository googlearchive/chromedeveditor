
    addEventListener('template-bound', function(e) {
      // setup
      var simple = document.querySelector('#simple');
      var sectioned = document.querySelector('#sectioned');

      function testWhenOpen(element, test, next) {
        var l1 = function() {
          test();
          element.async(function() {
            element.opened = false;
          }, null, 1);
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
        // scrolling overlay does not overflow
        function(next) {
          testWhenOpen(simple, function() {
            var rect = simple.getBoundingClientRect();
            chai.assert.ok(0 < rect.top + 10, 'overlay constrained to window size');
            chai.assert.ok(0 < rect.left + 10, 'overlay constrained to window size');
            chai.assert.ok(window.innerWidth >= rect.right + 10, 'overlay constrained to window size');
            chai.assert.ok(window.innerHeight >= rect.bottom + 10, 'overlay constrained to window size');
          }, next);
        },
        // scrolling overlay does not overflow
        function(next) {
          testWhenOpen(sectioned, function() {
            var rect = sectioned.getBoundingClientRect();
            chai.assert.ok(0 < rect.top + 10, 'overlay constrained to window size');
            chai.assert.ok(0 < rect.left + 10, 'overlay constrained to window size');
            chai.assert.ok(window.innerWidth >= rect.right + 10, 'overlay constrained to window size');
            chai.assert.ok(window.innerHeight >= rect.bottom + 10, 'overlay constrained to window size');
          }, next);
        },
        // positioned scrolling overlay does not overflow
        function(next) {
          sectioned.style.top = sectioned.style.right = '';
          sectioned.style.left = '300px';
          sectioned.style.bottom = '200px'
          testWhenOpen(sectioned, function() {
            var rect = sectioned.getBoundingClientRect();
            chai.assert.ok(0 < rect.top + 10, 'overlay constrained to window size');
            chai.assert.ok(0 < rect.left + 10, 'overlay constrained to window size');
            chai.assert.ok(window.innerWidth >= rect.right + 10, 'overlay constrained to window size');
            chai.assert.ok(window.innerHeight >= rect.bottom + 10, 'overlay constrained to window size');
          }, next);
        }
      ], done);
    });
  