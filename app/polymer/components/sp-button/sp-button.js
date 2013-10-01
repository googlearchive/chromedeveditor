Polymer('sp-button', {
  created: function() {
    // Do something when the instance is created.
  },
  active: false,
  activeChanged: function() {
    console.log('active ' + this.active);
  }
});
