
  document.addEventListener('polymer-ready', function() {
    // setup
    // basic
    var basic = document.querySelector('#basic');
    // targeted
    var target = document.querySelector('#target');
    var targeted = document.querySelector('#targeted');
    targeted.target = target;
    // 
    var layered = document.querySelector('#layered');
    var backdrop = document.querySelector('#backdrop');

    function testOpenEvents(element, next) {
      var openingEvents = 0;
      element.addEventListener('core-overlay-open', function() {
        openingEvents++;
      });
      element.addEventListener('core-overlay-open-completed', function() {
        openingEvents++;
        element.async(function() {
          this.opened = false;
        }, 1);
      });
      element.addEventListener('core-overlay-close-completed', function() {
        openingEvents++;
        chai.assert.equal(openingEvents, 4, 'open and open-completed events fired');
        next();
      });
      element.opened = true;
    }

    asyncSeries([
      // basic overlay events
      function(next) {
        chai.assert.equal(basic.opened, false, 'overlay starts closed');
        chai.assert.equal(getComputedStyle(basic).display, 'none', 'overlay starts hidden');
        testOpenEvents(basic, next);
        
      },
      // targeted overlay events
      function(next) {
        chai.assert.equal(targeted.opened, false, 'targeted overlay starts closed');
        chai.assert.equal(getComputedStyle(target).display, 'none', 'targeted overlay target starts hidden');
        testOpenEvents(targeted, next);
      },
      // layered overlay events
      function(next) {
        testOpenEvents(layered, next);
      },
      // backdrop overlay events
      function(next) {
        testOpenEvents(backdrop, next);
      }
    ], done);
  });

