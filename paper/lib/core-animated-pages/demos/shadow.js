
      Polymer('grid-toc', {
        selectedChanged: function(old) {
          this.lastSelected = old;
        },
        selectView: function(e) {
          var item = e.target.templateInstance.model.item;
          if (item !== undefined) {
            this.fire('grid-toc-select', {item: item});
          }
        }
      });
    