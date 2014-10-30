

    var s = document.querySelector('#selector');

    suite('activate event', function() {

      test('activates on tap', function(done) {
        assert.equal(s.selected, '0');

        async.nextTick(function() {
          // select Item 2
          s.children[1].dispatchEvent(new CustomEvent('tap', {bubbles: true}));
        });

        s.addEventListener("core-activate", function(event) {
          assert.equal(event.detail.item, s.children[1]);
          assert.equal(s.selected, 1);
          done();
        });
      });

    });

  