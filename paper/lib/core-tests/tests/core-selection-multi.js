
    document.addEventListener('polymer-ready', function() {
      var s = document.querySelector('core-selection');
      s.addEventListener("core-select", function(event) {
        if (test === 1) {
          // check test1
          assert.isTrue(event.detail.isSelected);
          assert.equal(event.detail.item, '(item1)');
          assert.isTrue(s.isSelected(event.detail.item));
          assert.equal(s.getSelection().length, 1);
          // test2
          test++;
          s.select('(item2)');
        } else if (test === 2) {
          // check test2
          assert.isTrue(event.detail.isSelected);
          assert.equal(event.detail.item, '(item2)');
          assert.isTrue(s.isSelected(event.detail.item));
          assert.equal(s.getSelection().length, 2);
          done();
        }
      });
      // test1
      var test = 1;
      s.select('(item1)');
    });
  