
    document.addEventListener('polymer-ready', function() {
      var assert = chai.assert;
      var s = document.querySelector('#selector');
      s.addEventListener("core-activate", function(event) {
        assert.equal(event.detail.item, s.children[1]);
        assert.equal(s.selected, 1);
        done();
      });
      assert.equal(s.selected, '0');
      requestAnimationFrame(function() {
        s.children[1].dispatchEvent(new CustomEvent('tap', {bubbles: true}));
      });
    });
  