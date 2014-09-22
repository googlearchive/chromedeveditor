

  Polymer({

    publish: {
      page: {value: 0}
    },

    selectedItem: null,
    noTransition: true,

    back: function() {
      this.noTransition = true;
      this.fire('nested-back');
    },

    transition: function() {
      this.noTransition = false;
      this.page = this.page === 0 ? 1 : 0;
    }

  });
