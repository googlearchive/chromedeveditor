
    var async = requestAnimationFrame;
    
    function oneMutation(node, options, cb) {
      var o = new MutationObserver(function() {
        cb();
        o.disconnect();
      });
      o.observe(node, options);
    }
    
    document.addEventListener('polymer-ready', function() {
      var assert = chai.assert;
      // selector1
      var s = document.querySelector('#selector1');
      assert.equal(s.selected, null);
      assert.equal(s.selectedClass, 'core-selected');
      assert.isFalse(s.multi);
      assert.equal(s.valueattr, 'name');
      assert.equal(s.items.length, 5);
      // selector2
      s = document.querySelector('#selector2');
      assert.equal(s.selected, "item3");
      assert.equal(s.selectedClass, 'my-selected');
      // setup listener for core-select event
      var selectEventCounter = 0;
      s.addEventListener('core-select', function(e) {
        if (e.detail.isSelected) {
          selectEventCounter++;
          // selectedItem and detail.item should be the same
          assert.equal(e.detail.item, s.selectedItem);
        }
      });
      // set selected
      s.selected = 'item5';
      Platform.flush();
      setTimeout(function() {
        // check core-select event
        assert.equal(selectEventCounter, 1);
        // check selected class
        assert.isTrue(s.children[4].classList.contains('my-selected'));
        // check selectedItem
        assert.equal(s.selectedItem, s.children[4]);
        // selecting the same value shouldn't fire core-select
        selectEventCounter = 0;
        s.selected = 'item5';
        Platform.flush();
        // TODO(ffu): would be better to wait for something to happen
        // instead of not to happen
        setTimeout(function() {
          assert.equal(selectEventCounter, 0);
          done();
        }, 50);
      }, 50);
    });
  