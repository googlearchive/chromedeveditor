
    var delay = 200;
    document.addEventListener('polymer-ready', function() {
      var c = document.querySelector('#collapse');
      // verify take attribute for opened is correct
      assert.equal(c.opened, true);
      setTimeout(function() {
        // get the height for the opened state
        var h = getCollapseComputedStyle().height;
        // verify the height is not 0px
        assert.notEqual(getCollapseComputedStyle().height, '0px');
        // close it
        c.opened = false;
        Platform.flush();
        setTimeout(function() {
          // verify is closed
          assert.notEqual(getCollapseComputedStyle().height, h);
          // open it
          c.opened = true;
          Platform.flush();
          setTimeout(function() {
            // verify is opened
            assert.equal(getCollapseComputedStyle().height, h);
            done();
          }, delay);
        }, delay);
      }, delay);
    });
    
    function getCollapseComputedStyle() {
      var b = document.querySelector('#collapse');
      return getComputedStyle(b);
    }
    
  