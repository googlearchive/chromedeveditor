

    document.addEventListener('polymer-ready', function() {
      var assert = chai.assert;
      var s = document.querySelector('#selector');
      var t = document.querySelector('#itemsTemplate');
      t.model = {items: ['Item1', 'Item2', 'Item3', "Item4"]};
      Platform.flush();
      setTimeout(function() {
        // check items
        assert.equal(s.items.length, 4);
        assert.equal(s.selected, 1);
        // check selectedItem
        var item = s.selectedItem;
        assert.equal(s.items[1], item);
        // check selected class
        assert.isTrue(item.classList.contains('core-selected'));
        done();
      }, 50);
    });

  