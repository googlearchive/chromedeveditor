

    Polymer('quiz-demo', {

      page: 0,

      transition: function(e) {
        if (this.page === 2) {
          this.page = 0;
        } else {
          this.page += 1;
        }
      }
    });

  