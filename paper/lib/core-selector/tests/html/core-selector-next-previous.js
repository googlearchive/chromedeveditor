
  
    function async(fn) {
      setTimeout(function() {
        fn();
        Platform.flush();
      }, 50);
    }

    document.addEventListener('polymer-ready', function() {
      var assert = chai.assert;
      var s = document.querySelector('#selector');
      assert.equal(s.selected, 0);
      async(function() {
        // select next item
        s.selectNext();
        async(function() {
          assert.equal(s.selected, 1);
          // select next item
          s.selectNext();
          async(function() {
            assert.equal(s.selected, 2);
            // select next item (already at the end)
            s.selectNext();
            async(function() {
              assert.equal(s.selected, 2);
              // select previous item
              s.selectPrevious();
              async(function() {
                assert.equal(s.selected, 1);
                // select previous item
                s.selectPrevious();
                async(function() {
                  assert.equal(s.selected, 0);
                  // select previous item (already at the beginning)
                  s.selectPrevious();
                  async(function() {
                    assert.equal(s.selected, 0);
                    done();
                  });
                });
              });
            });
          });
        });
      });
    });

  