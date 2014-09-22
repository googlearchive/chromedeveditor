

    Polymer('nested-demo', {

      page: 0,
      subpage: 0,

      transition: function(e) {

        var el = e.target;
        if (el.id === "thing1") {
          this.subpage = 0;
        } else {
          this.subpage = 1;
        }

        setTimeout(function() {
          this.page = 1;
        }.bind(this), 200);
      },

      back: function() {
        this.page = 0;
      }

    });

  