
         Polymer('selection-example', {
           itemTapAction: function(e, detail, sender) {
             this.$.selection.select(e.target);
           },
           selectAction: function(e, detail, sender) {
             detail.item.classList.toggle('selected', detail.isSelected);
           }
         });
       