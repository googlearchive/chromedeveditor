

    document.addEventListener('polymer-ready', function() {
      var assert = chai.assert;
      var s = document.querySelector('#selector');
      // select Item 4
      s.selected = 4;
      Platform.flush();
      setTimeout(function() {
        // check Item2's attribute and property (should be unselect)
        assert.isFalse(s.children[2].hasAttribute('active'));
        assert.notEqual(s.children[2].myprop, true);
        // check Item4's attribute and property
        assert.isTrue(s.children[4].hasAttribute('active'));
        assert.isTrue(s.children[4].myprop);
        done();
      }, 50);
    });

  