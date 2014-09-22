
    document.addEventListener('polymer-ready', function() {
      var s = document.querySelector('core-selection');
      s.addEventListener("core-select", function(event) {
        if (test === 1) {
          // check test1
          assert.isTrue(event.detail.isSelected);
          assert.equal(event.detail.item, '(item)');
          assert.isTrue(s.isSelected(event.detail.item));
          assert.isFalse(s.isSelected('(some_item_not_selected)'));
          // test2
          test++;
          s.select(null);
        } else if (test === 2) {
          // check test2
          assert.isFalse(event.detail.isSelected);
          assert.equal(event.detail.item, '(item)');
          assert.isFalse(s.isSelected(event.detail.item));
          done();
        }
      });
      // test1
      var test = 1;
      s.select('(item)');
    });
  