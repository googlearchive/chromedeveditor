

    var s1 = document.querySelector('#selector1');
    var s2 = document.querySelector('#selector2');

    suite('basic', function() {

      suite('defaults', function() {
        test('to nothing selected', function() {
          assert.equal(s1.selected, null);
        });

        test('to core-selected as selectedClass', function() {
          assert.equal(s1.selectedClass, 'core-selected');
        });

        test('to a single-select', function() {
          assert.isFalse(s1.multi);
        });

        test('to name as valueattr', function() {
          assert.equal(s1.valueattr, 'name');
        });

        test('as many items as children', function() {
          assert.equal(s1.items.length, 5);
        });
      });

      test('honors the selected attribute', function() {
        assert.equal(s2.selected, 'item3');
        assert.equal(s2.selectedIndex, 2);
        assert.equal(s2.selectedItem, document.querySelector('#item3'));
      });

      test('honors the selectedClass attribute', function() {
        assert.equal(s2.selectedClass, 'my-selected');
        assert.isTrue(document.querySelector('#item3').classList.contains('my-selected'));
      });

      test('allows assignment to selected', function(done) {
        // setup listener for core-select event
        var selectEventCounter = 0;
        s2.addEventListener('core-select', function(e) {
          if (e.detail.isSelected) {
            selectEventCounter++;
            // selectedItem and detail.item should be the same
            assert.equal(e.detail.item, s2.selectedItem);
          }
        });
        // set selected
        s2.selected = 'item5';
        asyncPlatformFlush(function() {
          // check core-select event
          assert.equal(selectEventCounter, 1);
          // check selected class
          assert.isTrue(s2.children[4].classList.contains('my-selected'));
          // check selectedItem
          assert.equal(s2.selectedItem, s2.children[4]);
          // selecting the same value shouldn't fire core-select
          selectEventCounter = 0;
          s2.selected = 'item5';
          asyncPlatformFlush(function() {
            assert.equal(selectEventCounter, 0);
            done();
          });
        });
      });

    });

  