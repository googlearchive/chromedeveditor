

    Polymer('music-demo', {

      page: 0,

      items: [
        { artist: 'Tycho', album: 'Fragments', color: '#f4db33' },
        { artist: 'Tycho', album: 'Past Prologue', color: '#972ff8' },
        { artist: 'Tycho', album: 'Spectre', color: '#7dd6fe' },
        { artist: 'Tycho', album: 'Awake', color: '#dc3c84' }
      ],

      selectedAlbum: null,

      transition: function(e) {
        if (this.page === 0 && e.target.templateInstance.model.item) {
          this.selectedAlbum = e.target.templateInstance.model.item;
          this.page = 1;
        } else {
          this.page = 0;
        }
      }
    });

  