

    var s = document.querySelector('#selector');

    suite('multi', function() {

      test('honors the multi attribute', function() {
        assert.isTrue(s.multi);
      });

      test('has sane defaults', function() {
        assert.equal(s.selected, null);
        assert.equal(s.selectedClass, 'core-selected');
        assert.equal(s.valueattr, 'name');
        assert.equal(s.items.length, 5);
      });

      test('allows multi-selection', function(done) {
        // setup listener for core-select event
        var selectEventCounter = 0;
        s.addEventListener('core-select', function(e) {
          if (e.detail.isSelected) {
            selectEventCounter++;
          } else {
            selectEventCounter--;
          }
          // check selectedItem in core-select event
          assert.equal(this.selectedItem.length, selectEventCounter);
        });
        // set selected
        s.selected = [0, 2];
        asyncPlatformFlush(function() {
          // check core-select event
          assert.equal(selectEventCounter, 2);
          // check selected class
          assert.isTrue(s.children[0].classList.contains('core-selected'));
          assert.isTrue(s.children[2].classList.contains('core-selected'));
          // check selectedItem
          assert.equal(s.selectedItem.length, 2);
          assert.equal(s.selectedItem[0], s.children[0]);
          assert.equal(s.selectedItem[1], s.children[2]);
          // tap on already selected element should unselect it
          s.children[0].dispatchEvent(new CustomEvent('tap', {bubbles: true}));
          // check selected
          assert.equal(s.selected.length, 1);
          assert.isFalse(s.children[0].classList.contains('core-selected'));
          done();
        });
      });

    });

  