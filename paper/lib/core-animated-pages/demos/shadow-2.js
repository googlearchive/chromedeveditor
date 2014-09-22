

    addEventListener('template-bound', function(e) {
      var scope = e.target;
      var items = [], count=50;
      for (var i=0; i < count; i++) {
        items.push(i);
      }

      scope.items = items;

      scope.selectView = function(e, detail) {
        var i = detail.item;
        this.$.pages.selected = i+1;
      }

      scope.back = function() {
        this.lastSelected = this.$.pages.selected;
        this.$.pages.selected = 0;
      }

      scope.transitionend = function() {
        if (this.lastSelected) {
          this.lastSelected = null;
        }
      }
    })

  