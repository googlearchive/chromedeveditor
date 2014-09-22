

    Polymer('list-demo', {

      selected: 0,

      items: [
        {h: 'matt', v: 'Matt McNulty'},
        {h: 'scott', v: 'Scott Miles'},
        {h: 'steve', v: 'Steve Orvell'},
        {h: 'frankie', v: 'Frankie Fu'},
        {h: 'daniel', v: 'Daniel Freedman'},
        {h: 'yvonne', v: 'Yvonne Yip'},
      ],

      items2: [
        {h: 'matt', v: 'Matt McNulty'},
        {h: 'scott', v: 'Scott Miles'},
        {h: 'steve', v: 'Steve Orvell'},
        {h: 'frankie', v: 'Frankie Fu'},
        {h: 'daniel', v: 'Daniel Freedman'},
        {h: 'yvonne', v: 'Yvonne Yip'},
      ],

      reorder: function(e) {
        if (this.$.pages.transitioning.length) {
          return;
        }

        this.lastMoved = e.target;
        this.lastMoved.style.zIndex = 10005;
        var item = e.target.templateInstance.model;
        var items = this.selected ? this.items : this.items2;
        var i = this.selected ? this.items2.indexOf(item) : this.items.indexOf(item);
        if (i != 0) {
          items.splice(0, 0, item);
          items.splice(i + 1, 1);
        }

        this.lastIndex = i;
        this.selected = this.selected ? 0 : 1;
      },

      done: function() {
        var i = this.lastIndex;
        var items = this.selected ? this.items : this.items2;
        var item = items[i];
        items.splice(0, 0, item);
        items.splice(i + 1, 1);
        this.lastMoved.style.zIndex = null;
      }
    });

  