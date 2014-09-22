
    var fake = new Fake();

    function centerOf(node) {
      var rect = node.getBoundingClientRect();
      return {x: rect.left + rect.width / 2, y: rect.top + rect.height / 2};
    }

    function approxEqual(p1, p2) {
      return Math.floor(p1.x) == Math.floor(p2.x) && Math.floor(p1.y) == Math.floor(p2.y);
    }

    function test1() {
      var ripple1 = document.querySelector('.ripple-1-tap');
      fake.downOnNode(ripple1, function() {

        requestAnimationFrame(function() {
          var wave = document.querySelector('.ripple-1 /deep/ .wave');
          chai.assert(approxEqual(centerOf(ripple1), centerOf(wave)), 'ripple position is incorrect in tall container');

          test2();
        });

      });
    }

    function test2() {
      var ripple1 = document.querySelector('.ripple-2-tap');
      fake.downOnNode(ripple1, function() {

        requestAnimationFrame(function() {
          var wave = document.querySelector('.ripple-2 /deep/ .wave');
          chai.assert(approxEqual(centerOf(ripple1), centerOf(wave)), 'ripple position is incorrect in wide container');

          done();
        });

      });
    }

    document.addEventListener('polymer-ready', test1);
  